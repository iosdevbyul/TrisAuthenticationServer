#!/usr/bin/env python3
"""Generate the static contract from simple Swift DTOs plus reviewed operation metadata.
This is deliberately a bounded extractor, not a general Swift parser. Unsupported DTO
syntax fails; compiled route/encoding tests independently check the generated result.
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Sources/TrisAuthenticationServer'
PACKAGE_SOURCE = ROOT / 'Packages/AuthenticationServerKit/Sources/AuthenticationServerKit'
OUTPUT = ROOT / 'docs/openapi/openapi.json'

def contract_source(path):
    candidates = [root / path for root in (SOURCE, PACKAGE_SOURCE) if (root / path).is_file()]
    assert len(candidates) == 1, f'Expected one contract source: {path}'
    return candidates[0]



def ref(name):
    return {'$ref': '#/components/schemas/' + name}


def object_schema(properties, required):
    return dict(type='object', properties=properties, required=required)


def generate():
    schemas = {}
    def swift_type(value):
        if value.startswith('[') and value.endswith(']'):
            return dict(type='array', items=swift_type(value[1:-1]))
        return {'String': {'type': 'string'}, 'Bool': {'type': 'boolean'},
                'Int': {'type': 'integer'}, 'Date': {'type': 'string', 'format': 'date-time'}}.get(value, ref(value))
    for file in sorted([p for root in (SOURCE, PACKAGE_SOURCE) for p in (root / 'DTOs').glob('*.swift')]):
        source = re.sub(r'\bpublic\s+', '', re.sub(r'//[^\n]*', '', file.read_text()))
        for name, body in re.findall(r'struct (\w+): Content \{(.*?)\n\}', source, re.S):
            if 'CodingKeys' in body or 'encode(' in body or 'decode(' in body:
                raise ValueError(f'{name}: custom coding requires extractor support')
            fields = re.findall(r'^\s*let (\w+): ([\w\[\]]+)(\?)?\s*$', body, re.M)
            if len(fields) != len(re.findall(r'^\s*(?:let|var) ', body, re.M)):
                raise ValueError(f'{name}: unsupported property declaration')
            assert name not in schemas, f'Duplicate DTO: {name}'
            schemas[name] = object_schema({key: swift_type(kind) for key, kind, _ in fields},
                                          [key for key, _, optional in fields if not optional])
    errors_source = contract_source('Errors/APIError.swift').read_text()
    codes = dict(re.findall(r'case (\w+) = "([A-Z_]+)"', errors_source))
    statuses = {}
    status_numbers = dict(badRequest=400, unauthorized=401, conflict=409, notFound=404,
                          tooManyRequests=429, payloadTooLarge=413, unsupportedMediaType=415,
                          forbidden=403, badGateway=502, internalServerError=500)
    switch = errors_source.split('var status: HTTPResponseStatus {', 1)[1].split('var message:', 1)[0]
    for cases, status in re.findall(r'case (.*?): return \.(\w+)', switch, re.S):
        for case in re.findall(r'\.(\w+)', cases):
            statuses[case] = status_numbers[status]
    assert set(statuses) == set(codes), 'Unmapped error status'
    schemas['APIErrorCode'] = dict(type='string', enum=list(codes.values()),
        description='Complete code catalog. Endpoint responses list reachable codes. FORBIDDEN and EMAIL_VERIFICATION_REQUIRED are not currently enforced by public handlers. HTTP_ERROR is the fallback for otherwise unmapped Abort statuses.',
        **{'x-default-status': {codes[k]: v for k, v in statuses.items()}})
    detail_source = contract_source('DTOs/APIErrorResponseDTO.swift').read_text()
    fields = re.search(r'enum Field:.*?\{ case (.*?) \}', detail_source).group(1).split(', ')
    detail_codes = re.findall(r'= "([A-Z_]+)"', detail_source)
    schemas['APIValidationDetail'] = object_schema(dict(field=dict(type='string', enum=fields), code=dict(type='string', enum=detail_codes)), ['field','code'])
    schemas['APIErrorResponseDTO']['properties']['error']['enum'] = [True]
    schemas['APIErrorResponseDTO']['description'] = 'status equals HTTP status; reason equals message (legacy compatibility). details is omitted when unavailable. No diagnostic or credential values are returned.'
    for name, schema in schemas.items():
        for field, prop in schema.get('properties', {}).items():
            if field in ('password','newPassword'):
                prop['description'] = '7–20 Swift Characters (extended grapheme clusters), at most 72 UTF-8 bytes. JSON Schema length cannot express this exactly.'
            if field == 'currentPassword':
                prop['description'] = 'Nonempty, at most 72 UTF-8 bytes; must match current password.'
            if field in ('email','newEmail') and 'Request' in name:
                prop['description'] = 'At most 254 UTF-8 bytes; must contain @ and a dot. Compared and stored exactly as supplied; no normalization or RFC email validator.'
            if field in ('token','refreshToken'):
                prop['description'] = 'Opaque credential; submitted tokens are checked for exactly 64 UTF-8 bytes. Never log or place in examples.'
            if field == 'accessToken':
                prop['description'] = 'Bearer JWT, approximately 15 minutes; requires a valid backing session.'
            if field == 'id':
                prop['format'] = 'uuid'
    schemas['ManagedSessionResponseDTO']['description'] = 'id is the stable management UUID. createdAt is current row creation; startedAt is login start (legacy fallback may differ); lastRefreshedAt records successful refresh only. ISO-8601 dates; missing optional fields are omitted.'
    schemas['SessionResponseDTO']['description'] = 'Both tokens are currently issued on success. refreshToken remains optional in the Swift DTO. Refresh lifetime is approximately 30 days.'
    metadata = json.loads((ROOT / 'docs/openapi/operations.json').read_text())
    controller = contract_source('Controllers/AuthController.swift').read_text()
    handlers = controller + contract_source('Controllers/SessionController.swift').read_text()
    paths = {}
    seen = set()
    for method, args, handler in re.findall(r'\.(get|post|delete)\(([^\n]+?), use: (\w+)\)', controller):
        path = '/auth/' + '/'.join('{' + s[1:] + '}' if s.startswith(':') else s for s in re.findall(r'"([^"]+)"', args))
        match = re.search(r'func '+handler+r'\(req: Request\) async throws -> (\w+) \{(.*?)(?=\n    (?:@Sendable|private func)|\n\})', handlers, re.S)
        assert match, handler
        response, body = match.groups()
        request = re.search(r'req.content.decode\((\w+).self\)', body)
        secured = 'AuthSession.payload(from: req)' in body or 'revokeSessions(req: req' in body
        meta = metadata[handler]
        seen.add(handler)
        error_names = set(meta['errors']) | {'internalError'}
        if request: error_names |= {'invalidRequest','unsupportedMediaType'}
        # Vapor collects request bodies for these routes before dispatch.
        error_names.add('payloadTooLarge')
        if secured: error_names |= {'authenticationRequired','accessTokenInvalidOrExpired','sessionInvalid'}
        responses = {'200': dict(description='Success', content={'application/json': dict(schema=ref(response))})}
        for status in sorted({statuses[e] for e in error_names}):
            allowed = sorted(codes[e] for e in error_names if statuses[e] == status)
            error_schema = {'allOf': [ref('APIErrorResponseDTO'), {'type':'object','properties':{'status':{'type':'integer','enum':[status]},'code':{'type':'string','enum':allowed}}}]}
            responses[str(status)] = dict(description=', '.join(allowed), content={'application/json':dict(schema=error_schema)})
        if handler == 'login':
            responses['429']['headers'] = {'Retry-After':dict(description='Seconds until retry (positive integer).',schema=dict(type='integer',minimum=1))}
        operation = dict(operationId=handler, summary=meta['summary'], description=meta['description'], security=[{'bearerAuth':[]}] if secured else [], responses=responses)
        if request:
            operation['requestBody'] = dict(required=True, content={media:dict(schema=ref(request.group(1))) for media in ['application/json','application/vnd.api+json','application/x-www-form-urlencoded','multipart/form-data']})
        parameters = []
        if '{sessionID}' in path:
            parameters.append(dict(name='sessionID', **{'in':'path'}, required=True, schema=dict(type='string',format='uuid'),description='Stable management ID returned by the session list.'))
        if handler in ('signUp','login'):
            parameters.append(dict(name='X-Device-Name', **{'in':'header'}, required=False, schema=dict(type='string'),description='One header, at most 128 UTF-8 bytes, no control characters. Trimmed; invalid or empty values are ignored.'))
        if handler in ('signUp','forgotPassword','resendVerificationEmail','requestEmailChange'):
            parameters.append(dict(name='X-Client-ID', **{'in':'header'}, required=False, schema=dict(type='string'),description='Optional untrusted abuse signal, never authentication. One header; trimmed nonempty value at most 128 UTF-8 bytes. Invalid values are ignored.'))
        if parameters: operation['parameters'] = parameters
        paths.setdefault(path,{})[method] = operation
    assert seen == set(metadata), 'Operation metadata and registered routes differ'
    paths['/hello'] = {'get':dict(operationId='hello',summary='Public greeting',description='Returns the plain-text greeting.',security=[],responses={'200':dict(description='Success',content={'text/plain':{'schema':{'type':'string'}}})})}
    paths['/hello']['get']['responses']['413'] = dict(description='PAYLOAD_TOO_LARGE (streamed request body exceeds collection limit)', content={'application/json':dict(schema=ref('APIErrorResponseDTO'))})
    return dict(openapi='3.0.3',info=dict(title='TrisAuthenticationServer public API',version='1.0.0',description='Contract baseline before AuthenticationServerKit extraction. Generated without running the server. JSON is the primary client format; current Vapor default form and JSON API decoders are also accepted. No query parameters are consumed. Unknown paths/methods return 404 NOT_FOUND using APIErrorResponseDTO. Infrastructure/proxy responses are outside this application contract.'),paths=paths,components=dict(schemas=schemas,securitySchemes={'bearerAuth':dict(type='http',scheme='bearer',bearerFormat='JWT',description='JWT sub, exp and sid are validated together with the active database session. Email verification is not required for current protected routes.')}))


def validate(document):
    from openapi_spec_validator import validate as validate_spec
    validate_spec(document)
    def walk(node):
        if isinstance(node,dict):
            if '$ref' in node:
                assert node['$ref'].startswith('#/'), 'External references are not allowed'
                target = document
                for part in node['$ref'][2:].split('/'):
                    target = target[part]
            assert not {'example','examples','default'} & node.keys(), 'Credential-free baseline has no examples/defaults'
            for value in node.values(): walk(value)
        elif isinstance(node,list):
            for value in node: walk(value)
    walk(document)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true',help='Validate and reject stale output without writing')
    args = parser.parse_args()
    document = generate()
    validate(document)
    rendered = json.dumps(document,ensure_ascii=False,indent=2,sort_keys=True)+'\n'
    if args.check:
        assert OUTPUT.read_text() == rendered, 'Stale OpenAPI document: run python scripts/openapi.py'
    else:
        OUTPUT.write_text(rendered)
    print(f'OpenAPI 3.0.3 valid; {sum(len(p) for p in document["paths"].values())} operations; references resolved; generated output current.')

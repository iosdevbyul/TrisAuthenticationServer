"""Regression checks for generation and validation; no server or database required."""
import unittest
from openapi import generate, validate


class OpenAPIValidationTests(unittest.TestCase):
    def test_broken_reference_is_rejected(self):
        document = generate()
        document['components']['schemas']['SessionResponseDTO']['properties']['user'] = {'$ref':'#/components/schemas/Missing'}
        with self.assertRaises(Exception):
            validate(document)

    def test_invalid_openapi_is_rejected(self):
        document = generate()
        del document['info']['title']
        with self.assertRaises(Exception):
            validate(document)

    def test_important_routes_and_contracts(self):
        document = generate()
        validate(document)
        paths = document['paths']
        self.assertEqual(sum(map(len, paths.values())), 18)
        protected = ['me','logout','withdraw','change-password','request-email-change',
                     'confirm-email-change','sessions','sessions/{sessionID}',
                     'logout-other-sessions','logout-all']
        for path in protected:
            for operation in paths['/auth/' + path].values():
                self.assertEqual(operation['security'], [{'bearerAuth':[]}])
        for path in ['signup','login','refresh','forgot-password','reset-password','verify-email','resend-verification-email']:
            self.assertEqual(paths['/auth/' + path]['post']['security'], [])
        self.assertIn('Retry-After', paths['/auth/login']['post']['responses']['429']['headers'])
        self.assertNotIn('headers', paths['/auth/request-email-change']['post']['responses']['429'])
        for path in ['signup','forgot-password','resend-verification-email']:
            self.assertNotIn('429', paths['/auth/' + path]['post']['responses'])
        self.assertEqual(paths['/auth/sessions']['get']['responses']['200']['content']['application/json']['schema']['$ref'], '#/components/schemas/SessionListResponseDTO')
        self.assertIn('404', paths['/auth/sessions/{sessionID}']['delete']['responses'])


if __name__ == '__main__':
    unittest.main()

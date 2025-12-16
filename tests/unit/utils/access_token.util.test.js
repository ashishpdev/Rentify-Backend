// tests/unit/utils/access_token.util.test.js
const AccessTokenUtil = require('../../../src/utils/access_token.util');

describe('AccessTokenUtil Unit Tests', () => {
  const validUserData = {
    user_id: 1,
    business_id: 1,
    branch_id: 1,
    role_id: 1,
    email: 'test@example.com',
    contact_number: '1234567890',
    user_name: 'Test User',
    business_name: 'Test Business',
    branch_name: 'Main Branch',
    role_name: 'Owner',
    is_owner: true,
  };

  describe('generateAccessToken', () => {
    it('should generate a valid access token with all required fields', () => {
      const result = AccessTokenUtil.generateAccessToken(validUserData);

      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('expiresAt');
      expect(result).toHaveProperty('expiresIn');
      expect(typeof result.accessToken).toBe('string');
      expect(result.accessToken.split('.')).toHaveLength(3);
    });

    it('should throw error when required field is missing', () => {
      const invalidData = { ...validUserData };
      delete invalidData.user_id;

      expect(() => {
        AccessTokenUtil.generateAccessToken(invalidData);
      }).toThrow('Missing required field: user_id');
    });

    it('should throw error when field is null', () => {
      const invalidData = { ...validUserData, email: null };

      expect(() => {
        AccessTokenUtil.generateAccessToken(invalidData);
      }).toThrow('Missing required field: email');
    });

    it('should generate different tokens for same data', () => {
      const token1 = AccessTokenUtil.generateAccessToken(validUserData);
      const token2 = AccessTokenUtil.generateAccessToken(validUserData);

      expect(token1.accessToken).not.toBe(token2.accessToken);
    });
  });

  describe('decryptAccessToken', () => {
    it('should decrypt a valid token and return user data', () => {
      const { accessToken } = AccessTokenUtil.generateAccessToken(validUserData);
      const decrypted = AccessTokenUtil.decryptAccessToken(accessToken);

      expect(decrypted.user_id).toBe(validUserData.user_id);
      expect(decrypted.email).toBe(validUserData.email);
      expect(decrypted.business_id).toBe(validUserData.business_id);
      expect(decrypted.iat).toBeUndefined();
      expect(decrypted.exp).toBeUndefined();
    });

    it('should throw error for invalid token format', () => {
      expect(() => {
        AccessTokenUtil.decryptAccessToken('invalid.token');
      }).toThrow();
    });

    it('should throw error for null token', () => {
      expect(() => {
        AccessTokenUtil.decryptAccessToken(null);
      }).toThrow('Invalid token format');
    });

    it('should throw error for tampered token', () => {
      const { accessToken } = AccessTokenUtil.generateAccessToken(validUserData);
      const tamperedToken = accessToken.slice(0, -5) + 'XXXXX';

      expect(() => {
        AccessTokenUtil.decryptAccessToken(tamperedToken);
      }).toThrow('Access token has been tampered with');
    });

    it('should detect expired tokens', (done) => {
      process.env.ACCESS_TOKEN_EXPIRES_MIN = '0.01';

      const { accessToken } = AccessTokenUtil.generateAccessToken(validUserData);

      setTimeout(() => {
        expect(() => {
          AccessTokenUtil.decryptAccessToken(accessToken);
        }).toThrow('Access token expired');
        
        process.env.ACCESS_TOKEN_EXPIRES_MIN = '15';
        done();
      }, 1000);
    });

    it('should reject token with wrong type', () => {
      const jwt = require('jsonwebtoken');
      const wrongTypeToken = jwt.sign(
        { ...validUserData, type: 'session_token' },
        process.env.TOKEN_SIGNING_KEY || 'dev-insecure-token-signing-key-do-not-use-in-prod',
        { expiresIn: '15m' }
      );

      expect(() => {
        AccessTokenUtil.decryptAccessToken(wrongTypeToken);
      }).toThrow('Invalid token type');
    });
  });

  describe('isValidTokenStructure', () => {
    it('should return true for valid JWT structure', () => {
      const { accessToken } = AccessTokenUtil.generateAccessToken(validUserData);
      expect(AccessTokenUtil.isValidTokenStructure(accessToken)).toBe(true);
    });

    it('should return false for invalid structures', () => {
      expect(AccessTokenUtil.isValidTokenStructure('invalid')).toBe(false);
      expect(AccessTokenUtil.isValidTokenStructure('')).toBe(false);
      expect(AccessTokenUtil.isValidTokenStructure(null)).toBe(false);
      expect(AccessTokenUtil.isValidTokenStructure(undefined)).toBe(false);
      expect(AccessTokenUtil.isValidTokenStructure('one.two')).toBe(false);
    });

    it('should return true for valid structure even if content is invalid', () => {
      const fakeToken = 'header.payload.signature';
      expect(AccessTokenUtil.isValidTokenStructure(fakeToken)).toBe(true);
    });
  });

  describe('Edge Cases and Security', () => {
    it('should handle special characters in user data', () => {
      const specialData = {
        ...validUserData,
        user_name: "O'Brien & Sons <script>alert('xss')</script>",
        email: 'test+tag@example.com',
      };

      const { accessToken } = AccessTokenUtil.generateAccessToken(specialData);
      const decrypted = AccessTokenUtil.decryptAccessToken(accessToken);

      expect(decrypted.user_name).toBe(specialData.user_name);
      expect(decrypted.email).toBe(specialData.email);
    });

    it('should handle unicode characters', () => {
      const unicodeData = {
        ...validUserData,
        user_name: '测试用户 🚀',
        business_name: 'Société Française',
      };

      const { accessToken } = AccessTokenUtil.generateAccessToken(unicodeData);
      const decrypted = AccessTokenUtil.decryptAccessToken(accessToken);

      expect(decrypted.user_name).toBe(unicodeData.user_name);
      expect(decrypted.business_name).toBe(unicodeData.business_name);
    });

    it('should handle large user_id values', () => {
      const largeIdData = {
        ...validUserData,
        user_id: Number.MAX_SAFE_INTEGER,
      };

      const { accessToken } = AccessTokenUtil.generateAccessToken(largeIdData);
      const decrypted = AccessTokenUtil.decryptAccessToken(accessToken);

      expect(decrypted.user_id).toBe(largeIdData.user_id);
    });

    it('should handle boolean is_owner correctly', () => {
      const ownerTrue = { ...validUserData, is_owner: true };
      const ownerFalse = { ...validUserData, is_owner: false };

      const token1 = AccessTokenUtil.generateAccessToken(ownerTrue);
      const token2 = AccessTokenUtil.generateAccessToken(ownerFalse);

      expect(AccessTokenUtil.decryptAccessToken(token1.accessToken).is_owner).toBe(true);
      expect(AccessTokenUtil.decryptAccessToken(token2.accessToken).is_owner).toBe(false);
    });
  });
});
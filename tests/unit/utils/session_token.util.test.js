// tests/unit/utils/session_token.util.test.js
const SessionTokenUtil = require('../../../src/utils/session_token.util');

describe('SessionTokenUtil Unit Tests', () => {
  const validSessionData = {
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
    device_id: 'device_123',
    ip_address: '192.168.1.1',
  };

  beforeAll(() => {
    if (!process.env.SESSION_ENCRYPTION_KEY) {
      process.env.SESSION_ENCRYPTION_KEY = 'test-encryption-key-32-chars-long';
    }
  });

  describe('generateSessionToken', () => {
    it('should generate a valid session token', () => {
      const result = SessionTokenUtil.generateSessionToken(validSessionData);

      expect(result).toHaveProperty('sessionToken');
      expect(result).toHaveProperty('expiresAt');
      expect(result).toHaveProperty('expiresIn');
      expect(result).toHaveProperty('createdAt');
      expect(typeof result.sessionToken).toBe('string');
    });

    it('should throw error when user_id is missing', () => {
      const invalidData = { ...validSessionData };
      delete invalidData.user_id;

      expect(() => {
        SessionTokenUtil.generateSessionToken(invalidData);
      }).toThrow('Missing required field: user_id');
    });

    it('should include metadata in token', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const decrypted = SessionTokenUtil.decryptSessionToken(sessionToken);

      expect(decrypted).toHaveProperty('iat');
      expect(decrypted).toHaveProperty('exp');
      expect(decrypted).toHaveProperty('created_at');
      expect(decrypted).toHaveProperty('expiry_at');
      expect(decrypted).toHaveProperty('session_life');
      expect(decrypted.type).toBe('session_token');
    });

    it('should generate unique tokens for same data', () => {
      const token1 = SessionTokenUtil.generateSessionToken(validSessionData);
      const token2 = SessionTokenUtil.generateSessionToken(validSessionData);

      expect(token1.sessionToken).not.toBe(token2.sessionToken);
    });

    it('should set correct expiry time', () => {
      const { expiresAt, createdAt } = SessionTokenUtil.generateSessionToken(validSessionData);
      
      const diffMs = expiresAt.getTime() - createdAt.getTime();
      const diffMinutes = Math.floor(diffMs / (1000 * 60));
      
      expect(diffMinutes).toBe(60);
    });
  });

  describe('decryptSessionToken', () => {
    it('should decrypt valid token correctly', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const decrypted = SessionTokenUtil.decryptSessionToken(sessionToken);

      expect(decrypted.user_id).toBe(validSessionData.user_id);
      expect(decrypted.email).toBe(validSessionData.email);
      expect(decrypted.device_id).toBe(validSessionData.device_id);
    });

    it('should throw error for invalid token format', () => {
      expect(() => {
        SessionTokenUtil.decryptSessionToken('invalid-token');
      }).toThrow();
    });

    it('should throw error for null or undefined token', () => {
      expect(() => {
        SessionTokenUtil.decryptSessionToken(null);
      }).toThrow('Invalid token format');

      expect(() => {
        SessionTokenUtil.decryptSessionToken(undefined);
      }).toThrow('Invalid token format');
    });

    it('should detect tampered tokens', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const tampered = sessionToken.slice(0, -5) + 'XXXXX';

      expect(() => {
        SessionTokenUtil.decryptSessionToken(tampered);
      }).toThrow('Session token has been tampered with');
    });

    it('should detect corrupted tokens', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const buffer = Buffer.from(sessionToken, 'base64');
      buffer[20] = buffer[20] ^ 0xFF;
      const corrupted = buffer.toString('base64');

      expect(() => {
        SessionTokenUtil.decryptSessionToken(corrupted);
      }).toThrow();
    });
  });

  describe('generateExtendedSessionToken', () => {
    it('should generate extended token from existing session', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const existingData = SessionTokenUtil.decryptSessionToken(sessionToken);
      
      const extended = SessionTokenUtil.generateExtendedSessionToken(existingData);

      expect(extended).toHaveProperty('sessionToken');
      expect(extended).toHaveProperty('expiresAt');
      expect(extended.sessionToken).not.toBe(sessionToken);
    });

    it('should preserve user data in extended token', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const existingData = SessionTokenUtil.decryptSessionToken(sessionToken);
      
      const { sessionToken: extendedToken } = SessionTokenUtil.generateExtendedSessionToken(existingData);
      const extendedData = SessionTokenUtil.decryptSessionToken(extendedToken);

      expect(extendedData.user_id).toBe(existingData.user_id);
      expect(extendedData.email).toBe(existingData.email);
      expect(extendedData.business_id).toBe(existingData.business_id);
    });

    it('should update expiry time', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const existingData = SessionTokenUtil.decryptSessionToken(sessionToken);
      
      const { sessionToken: extendedToken } = SessionTokenUtil.generateExtendedSessionToken(existingData);
      const extendedData = SessionTokenUtil.decryptSessionToken(extendedToken);

      expect(extendedData.exp).toBeGreaterThan(existingData.exp);
    });
  });

  describe('validateSessionToken', () => {
    it('should return valid for good token', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const result = SessionTokenUtil.validateSessionToken(sessionToken);

      expect(result.isValid).toBe(true);
      expect(result.sessionData).toBeDefined();
      expect(result.error).toBeNull();
    });

    it('should return invalid for bad token', () => {
      const result = SessionTokenUtil.validateSessionToken('bad-token');

      expect(result.isValid).toBe(false);
      expect(result.sessionData).toBeNull();
      expect(result.error).toBeDefined();
    });
  });

  describe('isValidTokenStructure', () => {
    it('should return true for valid structure', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      expect(SessionTokenUtil.isValidTokenStructure(sessionToken)).toBe(true);
    });

    it('should return false for invalid structures', () => {
      expect(SessionTokenUtil.isValidTokenStructure('invalid')).toBe(false);
      expect(SessionTokenUtil.isValidTokenStructure('')).toBe(false);
      expect(SessionTokenUtil.isValidTokenStructure(null)).toBe(false);
      expect(SessionTokenUtil.isValidTokenStructure(undefined)).toBe(false);
    });

    it('should return false for too short base64', () => {
      const shortBase64 = Buffer.from('short').toString('base64');
      expect(SessionTokenUtil.isValidTokenStructure(shortBase64)).toBe(false);
    });
  });

  describe('getRemainingTime', () => {
    it('should return positive seconds for valid token', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const remaining = SessionTokenUtil.getRemainingTime(sessionToken);

      expect(remaining).toBeGreaterThan(0);
      expect(remaining).toBeLessThanOrEqual(3600);
    });

    it('should return 0 for invalid token', () => {
      const remaining = SessionTokenUtil.getRemainingTime('invalid');
      expect(remaining).toBe(0);
    });
  });

  describe('Security and Edge Cases', () => {
    it('should handle special characters in session data', () => {
      const specialData = {
        ...validSessionData,
        user_name: "Test<>User'\"&",
        ip_address: '::1',
      };

      const { sessionToken } = SessionTokenUtil.generateSessionToken(specialData);
      const decrypted = SessionTokenUtil.decryptSessionToken(sessionToken);

      expect(decrypted.user_name).toBe(specialData.user_name);
      expect(decrypted.ip_address).toBe(specialData.ip_address);
    });

    it('should handle different encryption keys', () => {
      const originalKey = process.env.SESSION_ENCRYPTION_KEY;
      
      process.env.SESSION_ENCRYPTION_KEY = 'key1-32-characters-long-string';
      const { sessionToken: token1 } = SessionTokenUtil.generateSessionToken(validSessionData);

      process.env.SESSION_ENCRYPTION_KEY = 'key2-32-characters-long-string';
      
      expect(() => {
        SessionTokenUtil.decryptSessionToken(token1);
      }).toThrow();

      process.env.SESSION_ENCRYPTION_KEY = originalKey;
    });

    it('should reject tokens with modified IV', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const buffer = Buffer.from(sessionToken, 'base64');
      
      buffer[0] = buffer[0] ^ 0xFF;
      const modified = buffer.toString('base64');

      expect(() => {
        SessionTokenUtil.decryptSessionToken(modified);
      }).toThrow();
    });

    it('should reject tokens with modified auth tag', () => {
      const { sessionToken } = SessionTokenUtil.generateSessionToken(validSessionData);
      const buffer = Buffer.from(sessionToken, 'base64');
      
      buffer[20] = buffer[20] ^ 0xFF;
      const modified = buffer.toString('base64');

      expect(() => {
        SessionTokenUtil.decryptSessionToken(modified);
      }).toThrow('Session token has been tampered with');
    });
  });
});
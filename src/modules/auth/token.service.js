const TokenUtil = require("../../utils/token.util");
const { TOKEN_HEADERS } = require("../../constants/operations");

class TokenService {
  extractAccessToken(headers) {
    return headers[TOKEN_HEADERS.ACCESS] || null;
  }

  extractSessionToken(headers) {
    return headers[TOKEN_HEADERS.SESSION] || null;
  }

  validateAccessToken(token) {
    if (!TokenUtil.isValidTokenStructure(token)) {
      throw new Error("Invalid access token format");
    }

    const userData = TokenUtil.decryptAccessToken(token);
    if (!userData || !userData.user_id) {
      throw new Error("Invalid access token");
    }

    return userData;
  }
}

module.exports = new TokenService();

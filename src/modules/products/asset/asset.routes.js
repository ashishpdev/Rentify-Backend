const express = require("express");
const AssetController = require("./asset.controller");
const {
  requireBothTokens,
} = require("../../../middlewares/token-validation.middleware");

const router = express.Router();

// Asset Routes - All data from request body
router.post("/create", requireBothTokens, AssetController.createAsset);
router.post("/update", requireBothTokens, AssetController.updateAsset);
router.post("/get", requireBothTokens, AssetController.getAsset);
router.post("/list", requireBothTokens, AssetController.listAssets);
router.post("/delete", requireBothTokens, AssetController.deleteAsset);

module.exports = router;
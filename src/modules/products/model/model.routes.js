const express = require("express");
const ModelController = require("./model.controller");
const {
  requireBothTokens,
} = require("../../../middlewares/token-validation.middleware");

const router = express.Router();

// All routes now accept JSON body instead of multipart/form-data
router.post("/create", requireBothTokens, ModelController.createModel);
router.post("/update", requireBothTokens, ModelController.updateModel);
router.post("/get", requireBothTokens, ModelController.getModel);
router.post("/list", requireBothTokens, ModelController.listModels);
router.post("/delete", requireBothTokens, ModelController.deleteModel);

module.exports = router;
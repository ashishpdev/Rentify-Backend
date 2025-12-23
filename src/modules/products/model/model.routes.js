const express = require("express");
const multer = require("multer");
const tmpDir = "temp_uploads/";
const storage = multer.diskStorage({
  destination: tmpDir,
  filename: (req, file, cb) => cb(null, Date.now() + "_" + file.originalname),
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB per file
  fileFilter: (req, file, cb) => {
    if (!file.mimetype || !file.mimetype.startsWith("image/")) {
      return cb(new Error("Only image files are allowed"), false);
    }
    cb(null, true);
  },
});

// Custom error handler for multer
const handleMulterError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === "LIMIT_UNEXPECTED_FILE") {
      return res.status(400).json({
        success: false,
        message:
          'Invalid file field name. Use "images" as the field name for file uploads.',
        error: err.message,
      });
    }
    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({
        success: false,
        message: "File size too large. Maximum 5MB per file.",
        error: err.message,
      });
    }
  }
  if (err) {
    return res.status(400).json({
      success: false,
      message: err.message || "File upload error",
    });
  }
  next();
};

const ModelController = require("./model.controller");
const {
  requireBothTokens,
} = require("../../../middlewares/token-validation.middleware");

const router = express.Router();

router.post(
  "/create",
  requireBothTokens,
  upload.any(),
  handleMulterError,
  ModelController.createModel
);
router.post(
  "/update",
  requireBothTokens,
  upload.any(),
  handleMulterError,
  ModelController.updateModel
);
router.post("/get", requireBothTokens, ModelController.getModel);
router.post("/list", requireBothTokens, ModelController.listModels);
router.post("/delete", requireBothTokens, ModelController.deleteModel);

module.exports = router;

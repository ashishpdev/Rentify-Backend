const ResponseUtil = require("../../../utils/response.util");
const logger = require("../../../config/logger.config");
const { ModelValidator } = require("./model.validator");
const modelService = require("./model.service");
const driveService = require("../../google-drive/drive.service");

class ModelController {
  constructor() {
    // Bind all methods to preserve 'this' context
    this.createModel = this.createModel.bind(this);
    this.updateModel = this.updateModel.bind(this);
    this.getModel = this.getModel.bind(this);
    this.listModels = this.listModels.bind(this);
    this.deleteModel = this.deleteModel.bind(this);
    this._parseMultipartBody = this._parseMultipartBody.bind(this);
  }

  // helper: parse incoming multipart fields to typed object
  _parseMultipartBody(body) {
    const parsed = { ...body };
    // parse ints / floats if present
    const intFields = [
      "product_segment_id",
      "product_category_id",
      "product_model_id",
      "default_warranty_days",
    ];
    const floatFields = ["default_rent", "default_deposit", "default_sell"];

    intFields.forEach((f) => {
      if (parsed[f] !== undefined && parsed[f] !== null && parsed[f] !== "") {
        const v = parseInt(parsed[f], 10);
        parsed[f] = Number.isNaN(v) ? parsed[f] : v;
      }
    });
    floatFields.forEach((f) => {
      if (parsed[f] !== undefined && parsed[f] !== null && parsed[f] !== "") {
        const v = parseFloat(parsed[f]);
        parsed[f] = Number.isNaN(v) ? parsed[f] : v;
      }
    });

    // if product_model_images was sent as JSON string (e.g. on update), try to parse
    if (
      typeof parsed.product_model_images === "string" &&
      parsed.product_model_images.trim() !== ""
    ) {
      try {
        parsed.product_model_images = JSON.parse(parsed.product_model_images);
      } catch (err) {
        // leave as string — validation will fail later
      }
    }

    return parsed;
  }

  // ======================== CREATE MODEL ========================
  async createModel(req, res) {
    let uploadedFiles = null; // to cleanup if error
    try {
      // Check if request is multipart/form-data
      const contentType = req.headers["content-type"] || "";
      if (!contentType.includes("multipart/form-data")) {
        logger.warn("Invalid content-type for model creation", {
          contentType,
          expected: "multipart/form-data",
        });
        return ResponseUtil.badRequest(
          res,
          "Invalid request format. Use multipart/form-data with files for image upload."
        );
      }

      // 1) parse raw multipart body into typed values
      const raw = this._parseMultipartBody(req.body || {});

      // Reject if user tries to send product_model_images in body (images should come from files only)
      if (raw.product_model_images !== undefined) {
        return ResponseUtil.badRequest(
          res,
          "product_model_images should not be in request body. Upload images using multipart/form-data files."
        );
      }

      // 2) Validate user input FIRST (before file processing)
      const { error, value } = ModelValidator.validateCreateModel(raw);
      if (error) {
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // 3) Upload files from form-data and convert to image objects
      // Filter files to only accept those with fieldname 'images'
      const imageFiles = (req.files || []).filter(
        (f) => f.fieldname === "images"
      );

      if (imageFiles.length > 0) {
        uploadedFiles = await driveService.uploadMultiple(
          imageFiles,
          req.user.business_id,
          req.user.branch_id
        );

        // Convert uploaded files to image objects for database
        value.product_model_images = uploadedFiles.map((u, idx) => ({
          url: u.url,
          thumbnail_url: null,
          alt_text: u.original_name || u.file_name,
          file_size_bytes: u.size || null,
          width_px: null,
          height_px: null,
          is_primary: idx === 0,
          image_order: idx,
          product_model_image_category_id: 0,
        }));

        logger.info("Images uploaded and prepared", {
          count: uploadedFiles.length,
          images: value.product_model_images,
        });
      } else {
        // No files uploaded - set empty array
        value.product_model_images = [];
        logger.warn("No files uploaded for model creation");
      }

      // 4) Now proceed with validated data + images
      const userData = req.user;

      const result = await modelService.createModel(value, userData);
      if (!result.success) {
        // cleanup uploaded files (best-effort)
        if (uploadedFiles && uploadedFiles.length) {
          const ids = uploadedFiles
            .map((u) => driveService.extractDriveFileId(u.url))
            .filter(Boolean);
          await Promise.allSettled(
            ids.map((id) => driveService.deleteImage(id))
          );
        }
        return ResponseUtil.badRequest(res, result.message);
      }
      return ResponseUtil.created(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "createModel" });
      // cleanup uploaded files (best-effort) on unexpected exceptions
      if (uploadedFiles && uploadedFiles.length) {
        const ids = uploadedFiles
          .map((u) => driveService.extractDriveFileId(u.url))
          .filter(Boolean);
        await Promise.allSettled(ids.map((id) => driveService.deleteImage(id)));
      }
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to create model"
      );
    }
  }

  // ======================== UPDATE MODEL ========================
  async updateModel(req, res) {
    let uploadedFiles = null;
    try {
      // parse multipart body
      const raw = this._parseMultipartBody(req.body || {});

      // If new files attached, upload them first and attach to payload
      // Filter files to only accept those with fieldname 'images'
      const imageFiles = (req.files || []).filter(
        (f) => f.fieldname === "images"
      );

      if (imageFiles.length > 0) {
        uploadedFiles = await driveService.uploadMultiple(
          imageFiles,
          req.user.business_id,
          req.user.branch_id
        );

        const baseLen = Array.isArray(raw.product_model_images)
          ? raw.product_model_images.length
          : 0;

        const newImages = uploadedFiles.map((u, idx) => ({
          url: u.url,
          thumbnail_url: null,
          alt_text: u.original_name || u.file_name,
          file_size_bytes: u.size || null,
          width_px: null,
          height_px: null,
          is_primary: false, // Don't auto-set primary for new images in update
          image_order: baseLen + idx,
          product_model_image_category_id: 0,
        }));

        // Merge existing images (from body) with new uploaded images
        raw.product_model_images = (
          Array.isArray(raw.product_model_images)
            ? raw.product_model_images
            : []
        ).concat(newImages);
      }

      // Validate after upload & parsing
      const { error, value } = ModelValidator.validateUpdateModel(raw);
      if (error) {
        if (uploadedFiles && uploadedFiles.length) {
          const ids = uploadedFiles
            .map((u) => driveService.extractDriveFileId(u.url))
            .filter(Boolean);
          await Promise.allSettled(
            ids.map((id) => driveService.deleteImage(id))
          );
        }
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;

      // Prepare deletion file IDs to remove from Drive (best-effort) — parse from product_model_images array
      const fileIdsMarkedForDelete = (value.product_model_images || [])
        .filter((img) => img.is_deleted && img.url)
        .map((img) => driveService.extractDriveFileId(img.url))
        .filter(Boolean);

      const result = await modelService.updateModel(value, userData, {
        fileIdsMarkedForDelete,
      });

      if (!result.success) {
        // cleanup newly uploaded files on failure
        if (uploadedFiles && uploadedFiles.length) {
          const ids = uploadedFiles
            .map((u) => driveService.extractDriveFileId(u.url))
            .filter(Boolean);
          await Promise.allSettled(
            ids.map((id) => driveService.deleteImage(id))
          );
        }
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "updateModel" });
      if (uploadedFiles && uploadedFiles.length) {
        const ids = uploadedFiles
          .map((u) => driveService.extractDriveFileId(u.url))
          .filter(Boolean);
        await Promise.allSettled(ids.map((id) => driveService.deleteImage(id)));
      }
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to update model"
      );
    }
  }
  // ======================== GET MODEL ========================
  async getModel(req, res) {
    try {
      const { error, value } = ModelValidator.validateGetModel(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);
      const userData = req.user;
      const result = await modelService.getModel(
        value.product_model_id,
        userData
      );
      if (!result.success) return ResponseUtil.notFound(res, result.message);
      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "getModel" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to get model"
      );
    }
  }

  // ======================== LIST MODELS ========================
  async listModels(req, res) {
    try {
      const { error, value } = ModelValidator.validateListModels(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);
      const userData = req.user;
      const pagination = { page: value.page, limit: value.limit };
      const result = await modelService.listModels(userData, pagination);
      if (!result.success) return ResponseUtil.badRequest(res, result.message);
      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "listModels" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to list models"
      );
    }
  }

  // ======================== DELETE MODEL ========================
  async deleteModel(req, res) {
    try {
      const { error, value } = ModelValidator.validateDeleteModel(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);
      const userData = req.user;
      const result = await modelService.deleteModel(
        value.product_model_id,
        userData
      );
      if (!result.success) return ResponseUtil.badRequest(res, result.message);
      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "deleteModel" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to delete model"
      );
    }
  }
}

module.exports = new ModelController();

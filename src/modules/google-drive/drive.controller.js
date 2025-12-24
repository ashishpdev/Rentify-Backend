const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const driveService = require("./drive.service");
const HbsUtil = require("../../utils/hbs.util");
const PdfUtil = require("../../utils/pdf.util");

class DriveController {
    async upload(req, res) {
        try {
            const files = req.files;
            const user = req.user;

            if (!files?.length)
                return ResponseUtil.badRequest(res, "Images required");

            const uploaded = await driveService.uploadMultiple(
                files,
                user.business_id,
                user.branch_id
            );

            return ResponseUtil.created(
                res,
                uploaded,
                "Images uploaded successfully"
            );
        } catch (err) {
            logger.error("Upload error", err);
            return ResponseUtil.serverError(res, err.message || "Upload failed");
        }
    }

    async delete(req, res) {
        try {
            const fileId = req.params.file_id;
            await driveService.deleteImage(fileId);
            return ResponseUtil.success(res, null, "Deleted successfully");
        } catch (err) {
            logger.error("Drive delete error", err);
            return ResponseUtil.serverError(res, err.message || "Failed to delete");
        }
    }

    async update(req, res) {
        try {
            if (!req.file) return ResponseUtil.badRequest(res, "Image required");
            const fileId = req.params.file_id;
            await driveService.updateImage(fileId, req.file.path, req.file.mimetype);
            return ResponseUtil.success(res, null, "Updated successfully");
        } catch (err) {
            logger.error("Drive update error", err);
            return ResponseUtil.serverError(res, err.message || "Failed to update");
        }
    }

    async list(req, res) {
        try {
            const list = await driveService.listImages();
            return ResponseUtil.success(res, list, "Image list fetched");
        } catch (err) {
            logger.error("Drive list error", err);
            return ResponseUtil.serverError(
                res,
                err.message || "Failed to fetch list"
            );
        }
    }

    async getOne(req, res) {
        try {
            const data = await driveService.getImage(req.params.file_id);
            return ResponseUtil.success(res, data, "File detail fetched");
        } catch (err) {
            logger.error("Drive getOne error", err);
            return ResponseUtil.serverError(
                res,
                err.message || "Failed to fetch file"
            );
        }
    }

    // ============ INVOICE UPLOAD ============
    async uploadInvoicePdf(req, res) {
        try {
            const user = req.user;
            const data = req.body;

            /* -------- HBS → HTML -------- */
            const html = await HbsUtil.renderHbs("invoiceSentHtml5", data);

            /* -------- HTML → PDF BUFFER -------- */
            const pdfBuffer = await PdfUtil.htmlToPdf(html);

            if (!Buffer.isBuffer(pdfBuffer)) {
                throw new Error("PDF generation failed");
            }

            /* -------- UPLOAD TO DRIVE -------- */
            const upload = await driveService.uploadInovicePdf(
                pdfBuffer,
                user.business_id,
                user.branch_id
            );

            return ResponseUtil.created(res, upload, "PDF uploaded successfully");

        } catch (err) {
            logger.error("Upload error", err);
            return ResponseUtil.serverError(res, err.message || "Upload failed");
        }
    }

}

module.exports = new DriveController();

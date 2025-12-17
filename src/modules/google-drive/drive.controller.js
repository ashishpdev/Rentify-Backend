const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const driveService = require("./drive.service");
const HbsUtil = require("../../utils/hbs.util");
const PdfUtil = require("../../utils/pdf.util");

class DriveController {

    // ============ MULTIPLE UPLOAD ============
    async upload(req, res) {
        try {
            const files = req.files;
            const user = req.user; // must contain business_id & branch_id

            if (!files?.length)
                return ResponseUtil.badRequest(res, "Images required");

            const upload = await driveService.uploadMultiple(
                files,
                user.business_id,
                user.branch_id
            );

            return ResponseUtil.created(res, upload, "Images uploaded successfully");

        } catch (err) {
            logger.error("Upload error", err);
            return ResponseUtil.serverError(res, "Upload failed");
        }
    }

    // ============ DELETE ============
    async delete(req, res) {
        try {
            const msg = await driveService.deleteImage(req.params.file_id);
            return ResponseUtil.success(res, msg, "Deleted successfully");

        } catch (err) {
            return ResponseUtil.serverError(res, "Failed to delete");
        }
    }

    // ============ UPDATE ============
    async update(req, res) {
        try {
            if (!req.file) return ResponseUtil.badRequest(res, "Image required");

            const msg = await driveService.updateImage(req.params.file_id, req.file);
            return ResponseUtil.success(res, msg, "Updated successfully");

        } catch (err) {
            return ResponseUtil.serverError(res, "Failed to update");
        }
    }

    // ============ LIST ============
    async list(req, res) {
        try {
            const list = await driveService.listImages();
            return ResponseUtil.success(res, list, "Image list fetched");

        } catch (err) {
            return ResponseUtil.serverError(res, "Failed to fetch list");
        }
    }

    // ============ GET ONE ============
    async getOne(req, res) {
        try {
            const data = await driveService.getImage(req.params.file_id);
            return ResponseUtil.success(res, data, "File detail fetched");

        } catch (err) {
            return ResponseUtil.serverError(res, "Failed to fetch file");
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

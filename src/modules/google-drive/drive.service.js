const fs = require("fs");
const path = require("path");
const moment = require("moment");
const { Readable } = require("stream");
const { google } = require("googleapis");
const config = require("../../config/env.config");

// ==========================================
// CONFIGURATION & AUTH SETUP
// ==========================================

// 1. Credentials from env.config
const CLIENT_ID = config.drive.clientId;
const CLIENT_SECRET = config.drive.clientSecret;
const REFRESH_TOKEN = config.drive.refreshToken;
const FOLDER_ID = config.drive.folderId;
const INVOICE_FOLDER_ID = config.drive.invoiceFolderId;

// 2. OAuth Playground redirect (must match Google console)
const REDIRECT_URI = "https://developers.google.com/oauthplayground";

// 3. Initialize OAuth2 Client
const oauth2Client = new google.auth.OAuth2(
    CLIENT_ID,
    CLIENT_SECRET,
    REDIRECT_URI
);

// 4. Set Refresh Token (keeps access alive forever)
oauth2Client.setCredentials({ refresh_token: REFRESH_TOKEN });

// 5. Google Drive Instance
const drive = google.drive({ version: "v3", auth: oauth2Client });


class DriveService {

    // ==========================================
    // MULTIPLE IMAGE UPLOAD
    // ==========================================
    async uploadMultiple(files, businessId, branchId) {
        const time = moment().format("YYYYMMDD_HHmmss");

        // Process all uploads in parallel for maximum speed
        const uploadPromises = files.map((file, index) => {
            return new Promise(async (resolve, reject) => {
                const ext = path.extname(file.originalname);
                const fileName = `${businessId}_${branchId}_${time}_${index + 1}${ext}`;

                try {
                    // Upload to Drive
                    const res = await drive.files.create({
                        requestBody: {
                            name: fileName,
                            parents: [FOLDER_ID]
                        },
                        media: {
                            mimeType: file.mimetype,
                            body: fs.createReadStream(file.path)
                        },
                        fields: "id"
                    });

                    // Make public
                    await drive.permissions.create({
                        fileId: res.data.id,
                        requestBody: { role: "reader", type: "anyone" }
                    });

                    // Cleanup
                    if (fs.existsSync(file.path)) fs.unlinkSync(file.path);

                    resolve({
                        file_id: res.data.id,
                        file_name: fileName,
                        url: `https://drive.google.com/uc?id=${res.data.id}&export=view`
                    });

                } catch (error) {
                    console.error("Upload error:", error.message);

                    if (fs.existsSync(file.path)) fs.unlinkSync(file.path);

                    reject(new Error(`Drive upload failed: ${error.message}`));
                }
            });
        });

        // Wait for ALL uploads to complete
        return await Promise.all(uploadPromises);
    }


    // ==========================================
    // DELETE FILE
    // ==========================================
    async deleteImage(fileId) {
        try {
            await drive.files.delete({ fileId });
            return "Image deleted successfully";
        } catch (error) {
            console.error("Delete error:", error.message);
            throw new Error("Failed to delete image from Drive.");
        }
    }

    // ==========================================
    // UPDATE FILE
    // ==========================================
    async updateImage(fileId, file) {
        try {
            await drive.files.update({
                fileId,
                media: {
                    mimeType: file.mimetype,
                    body: fs.createReadStream(file.path)
                }
            });

            if (fs.existsSync(file.path)) {
                fs.unlinkSync(file.path);
            }

            return "Image updated successfully";
        } catch (error) {
            console.error("Update error:", error.message);
            throw new Error("Failed to update image on Drive.");
        }
    }

    // ==========================================
    // LIST ALL FILES
    // ==========================================
    async listImages() {
        try {
            const res = await drive.files.list({
                q: `'${FOLDER_ID}' in parents and trashed=false`,
                fields: "files(id, name)"
            });

            return res.data.files.map(f => ({
                file_id: f.id,
                file_name: f.name,
                url: `https://drive.google.com/uc?id=${f.id}&export=view`
            }));
        } catch (error) {
            console.error("List error:", error.message);
            throw new Error("Failed to list images.");
        }
    }

    // ==========================================
    // GET SINGLE FILE URL
    // ==========================================
    async getImage(fileId) {
        return {
            file_id: fileId,
            url: `https://drive.google.com/uc?id=${fileId}&export=view`
        };
    }


    // =========================================
    // UPLOAD SINGLE INVOICE PDF
    // =========================================
    // async uploadInovicePdf(file, businessId, branchId) {
    //     const time = moment().format("YYYYMMDD_HHmmss");

    //     if (!file) {
    //         throw new Error("No file provided");
    //     }

    //     // ❌ Allow only PDF
    //     if (file.mimetype !== "application/pdf") {
    //         if (fs.existsSync(file.path)) fs.unlinkSync(file.path);
    //         throw new Error("Only PDF files are allowed");
    //     }

    //     const ext = path.extname(file.originalname); // .pdf
    //     const fileName = `${businessId}_${branchId}_${time}${ext}`;

    //     try {
    //         // Upload to Google Drive
    //         const res = await drive.files.create({
    //             requestBody: {
    //                 name: fileName,
    //                 parents: [INVOICE_FOLDER_ID]
    //             },
    //             media: {
    //                 mimeType: file.mimetype,
    //                 body: fs.createReadStream(file.path)
    //             },
    //             fields: "id"
    //         });

    //         // Make file public
    //         await drive.permissions.create({
    //             fileId: res.data.id,
    //             requestBody: {
    //                 role: "reader",
    //                 type: "anyone"
    //             }
    //         });

    //         // Cleanup local file
    //         if (fs.existsSync(file.path)) fs.unlinkSync(file.path);

    //         return {
    //             file_id: res.data.id,
    //             file_name: fileName,
    //             url: `https://drive.google.com/uc?id=${res.data.id}&export=view`
    //         };

    //     } catch (error) {
    //         console.error("PDF upload error:", error.message);

    //         if (fs.existsSync(file.path)) fs.unlinkSync(file.path);

    //         throw new Error(`Drive upload failed: ${error.message}`);
    //     }
    // }

    async uploadInovicePdf(pdfBuffer, businessId, branchId) {
        if (!Buffer.isBuffer(pdfBuffer)) {
            throw new Error("Invalid PDF buffer received");
        }

        const time = moment().format("YYYYMMDD_HHmmss");
        const fileName = `${businessId}_${branchId}_${time}.pdf`;

        const bufferStream = Readable.from(pdfBuffer);

        const res = await drive.files.create({
            requestBody: {
                name: fileName,
                parents: [INVOICE_FOLDER_ID]
            },
            media: {
                mimeType: "application/pdf",
                body: bufferStream
            },
            fields: "id"
        });

        await drive.permissions.create({
            fileId: res.data.id,
            requestBody: { role: "reader", type: "anyone" }
        });

        return {
            file_id: res.data.id,
            file_name: fileName,
            url: `https://drive.google.com/uc?id=${res.data.id}&export=view`
        };
    }


}

module.exports = new DriveService();

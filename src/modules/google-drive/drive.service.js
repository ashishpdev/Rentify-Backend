// src/modules/google-drive/drive.service.js
const fs = require("fs");
const fsPromises = fs.promises;
const path = require("path");
const moment = require("moment");
const { Readable } = require("stream");
const { google } = require("googleapis");
const config = require("../../config/env.config");

const CLIENT_ID = config.drive.clientId;
const CLIENT_SECRET = config.drive.clientSecret;
const REFRESH_TOKEN = config.drive.refreshToken;
const FOLDER_ID = config.drive.folderId;
const INVOICE_FOLDER_ID = config.drive.invoiceFolderId;

// 2. OAuth Playground redirect (must match Google console)
const REDIRECT_URI = "https://developers.google.com/oauthplayground";

const oauth2Client = new google.auth.OAuth2(
  CLIENT_ID,
  CLIENT_SECRET,
  REDIRECT_URI
);
oauth2Client.setCredentials({ refresh_token: REFRESH_TOKEN });
const drive = google.drive({ version: "v3", auth: oauth2Client });

function extractDriveFileId(url) {
  if (!url) return null;
  const ucMatch = url.match(/[?&]id=([^&]+)/);
  if (ucMatch) return ucMatch[1];
  const dMatch = url.match(/\/d\/([^/]+)/);
  if (dMatch) return dMatch[1];
  return null;
}

class DriveService {
  async uploadFileStream({ filePath, fileName, mimeType }) {
    const res = await drive.files.create({
      requestBody: { name: fileName, parents: [FOLDER_ID] },
      media: { mimeType, body: fs.createReadStream(filePath) },
      fields: "id, name, size",
    });

    await drive.permissions.create({
      fileId: res.data.id,
      requestBody: { role: "reader", type: "anyone" },
    });
    const url = `https://drive.google.com/uc?id=${res.data.id}&export=view`;
    return {
      file_id: res.data.id,
      file_name: res.data.name,
      url,
      size: res.data.size,
    };
  }

  async uploadMultiple(files, businessId, branchId) {
    if (!Array.isArray(files) || files.length === 0)
      throw new Error("Files array required");
    const timestamp = Date.now();
    const uploads = files.map(async (file, index) => {
      const ext = path.extname(file.originalname) || "";
      const fileName = `${businessId}_${branchId}_${timestamp}_${index + 1}${ext}`;
      try {
        const result = await this.uploadFileStream({
          filePath: file.path,
          fileName,
          mimeType: file.mimetype,
        });
        try {
          await fsPromises.unlink(file.path);
        } catch (e) {
          /* ignore */
        }
        return {
          file_id: result.file_id,
          file_name: result.file_name,
          url: result.url,
          original_name: file.originalname,
          size: result.size,
        };
      } catch (err) {
        try {
          await fsPromises.unlink(file.path);
        } catch (e) {
          /* ignore */
        }
        throw err;
      }
    });
    return Promise.all(uploads);
  }

  async deleteImage(fileId) {
    if (!fileId) throw new Error("fileId required");
    try {
      await drive.files.delete({ fileId });
      return true;
    } catch (err) {
      throw new Error(`Drive delete failed: ${err.message}`);
    }
<<<<<<< HEAD


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


=======
  }

  async updateImage(fileId, filePath, mimeType) {
    if (!fileId) throw new Error("fileId required");
    try {
      await drive.files.update({
        fileId,
        media: { mimeType, body: fs.createReadStream(filePath) },
      });
      try {
        await fsPromises.unlink(filePath);
      } catch (e) {
        /* ignore */
      }
      return true;
    } catch (err) {
      try {
        await fsPromises.unlink(filePath);
      } catch (e) {}
      throw new Error(`Drive update failed: ${err.message}`);
    }
  }

  async listImages() {
    const res = await drive.files.list({
      q: `'${FOLDER_ID}' in parents and trashed=false`,
      fields: "files(id, name, mimeType, size)",
    });
    return res.data.files.map((f) => ({
      file_id: f.id,
      file_name: f.name,
      url: `https://drive.google.com/uc?id=${f.id}&export=view`,
      mimeType: f.mimeType,
      size: f.size,
    }));
  }

  async getImage(fileId) {
    const res = await drive.files.get({
      fileId,
      fields: "id,name,mimeType,size",
    });
    return {
      file_id: res.data.id,
      file_name: res.data.name,
      url: `https://drive.google.com/uc?id=${res.data.id}&export=view`,
      mimeType: res.data.mimeType,
      size: res.data.size,
    };
  }

  extractDriveFileId(url) {
    return extractDriveFileId(url);
  }
>>>>>>> 2ffa6556c6bee5448dc4f42bd66da6083f8c47ff
}

module.exports = new DriveService();

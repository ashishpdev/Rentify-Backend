const express = require("express");
const multer = require("multer");
const upload = multer({ dest: "temp_uploads/" });

const controller = require("./drive.controller");
const { requireBothTokens } = require("../../middlewares/token-validation.middleware");

const router = express.Router();

router.post("/upload", requireBothTokens, upload.array("images", 10), controller.upload);
router.get("/list",requireBothTokens, controller.list);
router.get("/detail/:file_id", requireBothTokens, controller.getOne);
router.put("/update/:file_id", requireBothTokens, upload.single("image"), controller.update);
router.delete("/delete/:file_id", requireBothTokens, controller.delete);
module.exports = router;

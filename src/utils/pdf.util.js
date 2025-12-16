const puppeteer = require("puppeteer");

class PdfUtil {
    static async htmlToPdf(html) {
        const browser = await puppeteer.launch({
            headless: true,
            args: [
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu"
            ]
        });

        const page = await browser.newPage();
        await page.setContent(html, { waitUntil: "networkidle0" });

        const pdfData = await page.pdf({
            format: "A4",
            printBackground: true
        });

        await browser.close();

        // ✅ FORCE CONVERT TO BUFFER
        return Buffer.from(pdfData);
    }
}

module.exports = PdfUtil;

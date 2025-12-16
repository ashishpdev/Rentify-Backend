const fs = require("fs");
const path = require("path");
const hbs = require("hbs");

// helper for index + 1
hbs.registerHelper("inc", v => v + 1);

class HbsUtil {
    async renderHbs(templateName, data) {
        const templatePath = path.join(
            __dirname,
            `../templates/${templateName}.hbs`
        );

        const source = fs.readFileSync(templatePath, "utf8");
        return hbs.compile(source)(data);
    };
}

module.exports = new HbsUtil;

# SharePoint HTML pages: sample pages

Two sample HTML pages used in the MSTechTalk series on SharePoint HTML pages. Upload either one to the **Site Pages** library of a SharePoint site where HTML pages are enabled, then open it from the library to see how SharePoint renders it.

| File | What it shows |
|---|---|
| [mst-it-service-desk-help.html](./sample-pages/mst-it-service-desk-help.html) | IT service desk help page: quick links, contact cards, a searchable FAQ and an opening-hours panel |
| [mst-new-starter-first-30-days.html](./sample-pages/mst-new-starter-first-30-days.html) | New starter page: a first-30-days checklist with progress, split into week one, weeks two to three and week four |

Both pages are a single file with inline CSS and JavaScript and no external scripts, fonts or images, so they work inside the sandboxed frame SharePoint uses for HTML pages. The checklist ticks are kept only in the browser tab; nothing is saved back to SharePoint.

Meridian Summit Technologies (MST) is a fictional company used on the author's demo tenant. Change the text, links and colours to match your own organisation before you use a page.

## How to use them

1. Download the `.html` file (open it on GitHub and choose **Download raw file**).
2. In your SharePoint site, go to **Site contents** > **Site Pages**.
3. Choose **Upload** > **Files** and pick the file. If the upload is refused, a site owner needs to check that HTML files are allowed for the library (**Site Pages** > **...** > **File types**).
4. Open the page from the library. Visitors need at least Read permission on the page.

Prefer to let Copilot build the page? The blog post covers both routes.

## Blog posts

- [How to create HTML pages in SharePoint with Copilot or your own file](https://mstechtalk.com/create-html-pages-sharepoint-copilot/)
- [SharePoint HTML pages and views: admin controls, security and PowerShell](https://mstechtalk.com/sharepoint-html-pages-admin-governance-powershell/)

The PowerShell reporting functions for HTML pages and dashboard views will be added to this folder with the admin post.

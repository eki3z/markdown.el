+++
title = "Example Post"
date = 2023-10-15
author = "John Doe"
tags = ["markdown", "toml", "example"]
draft = false

date = 2024-02-02T04:14:54-08:00
draft = false
title = 'Example'
weight = 10
[params]
  author = 'John Smith'
+++

# GitHub Flavored Markdown (GFM) Grammar Guide

GitHub Flavored Markdown extends standard Markdown with additional features like tables, task lists, and syntax highlighting. This guide covers all the GFM-supported syntax.

---

## Headers
# This is an H1
## This is an H2
### This is an H3
#### This is an H4
##### This is an H5
###### This is an H6

---

## Emphasis
**Bold text**  
*Italic text*  
***Bold and italic text***  
~~Strikethrough~~

---

## Lists

### Unordered List
- Item 1
  - Sub-item 1
  - Sub-item 2
- Item 2

### Ordered List
1. First item
2. Second item
   1. Sub-item 1
   2. Sub-item 2

---

## Task Lists
- [x] Task completed
- [ ] Task pending
- [ ] Another task

---

## Links
[Link to GitHub](https://github.com)  
[Relative Link](./example.md)

---

## Images
![Alt text](https://via.placeholder.com/150)

---

## Code Blocks

### Inline Code
Use `inline code` like this.

### Fenced Code Blocks
\`\`\`javascript
// JavaScript example
function greet() {
  console.log("Hello, GitHub!");
}
\`\`\`

### Syntax Highlighting
\`\`\`python
# Python example
def hello():
    print("Hello, GitHub!")
\`\`\`

---

## Tables
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Row 1    | Data 1   | Data 2   |
| Row 2    | Data 3   | Data 4   |

---

## Blockquotes
> This is a blockquote.  
> It can span multiple lines.

---

## Horizontal Rules
You can create a horizontal rule with:  
`---`, `***`, or `___`.

---

## Autolinks
Links and URLs are automatically converted:

https://github.com

---

## Strikethrough

~~This text is crossed out.~~

---

## Emoji
You can add emojis using their shortcodes:  
:smile: :rocket: :tada:  
(Full list available on [GitHub Emoji Cheat Sheet](https://github.com/ikatyang/emoji-cheat-sheet))

---

## Mentions and References
@username  
#123 (issue or pull request)  
github.com/repo#456 (full issue reference)

---

## Footnotes
Here is a sentence with a footnote.[^1]

[^1]: This is the footnote text.

---

## HTML Support
You can include raw HTML:  
<div style="color:blue;">This is blue text using HTML.</div>

---

## Escaping Characters
Escape characters using a backslash `\`:  
\- This renders a `-` as normal text.

---

## Checkbox Interactivity (Optional in Issues/PRs)
You can click on checkboxes directly in GitHub Issues or PRs:
- [x] Example interactive task
- [ ] Another task

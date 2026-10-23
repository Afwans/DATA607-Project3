# Run from the project root.
# Install packages if needed: install.packages(c("DiagrammeR", "DiagrammeRsvg", "rsvg", "htmlwidgets"))
library(DiagrammeR)

dot_file <- "ER_Diagram/Dataset1_ER_Diagram_Seven_Tables.dot"
dot_source <- paste(readLines(dot_file, warn = FALSE), collapse = "\n")
er_diagram <- DiagrammeR::grViz(dot_source)
er_diagram

if (requireNamespace("DiagrammeRsvg", quietly = TRUE) &&
    requireNamespace("rsvg", quietly = TRUE)) {
  svg_code <- DiagrammeRsvg::export_svg(er_diagram)
  rsvg::rsvg_png(charToRaw(svg_code),
                file = "ER_Diagram/Dataset1_ER_Diagram_Seven_Tables.png",
                width = 2400)
}

if (requireNamespace("htmlwidgets", quietly = TRUE)) {
  htmlwidgets::saveWidget(
    er_diagram,
    file = "ER_Diagram/Dataset1_ER_Diagram_Seven_Tables.html",
    selfcontained = TRUE
  )
}

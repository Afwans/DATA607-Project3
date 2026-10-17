# Run from the DATA607-Project3-Upload project root.
# Requires DiagrammeR, DiagrammeRsvg and rsvg.
library(DiagrammeR)

dot_file <- "ER_Diagram/Dataset1_ER_Diagram.dot"
dot_source <- paste(readLines(dot_file, warn = FALSE), collapse = "\n")
er_diagram <- DiagrammeR::grViz(dot_source)
er_diagram

if (requireNamespace("DiagrammeRsvg", quietly = TRUE) &&
    requireNamespace("rsvg", quietly = TRUE)) {
  svg_code <- DiagrammeRsvg::export_svg(er_diagram)
  rsvg::rsvg_png(charToRaw(svg_code),
                file = "ER_Diagram/Dataset1_ER_Diagram.png",
                width = 2400)
}

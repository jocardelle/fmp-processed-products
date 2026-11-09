# =============================================================================
# Figure style - Fishery Bulletin
# =============================================================================
#
# PURPOSE: One theme and one save step for every figure in 05-08, so the
#          figures match each other and the journal. Sourced at the top of
#          each figure script; not run on its own.
#
# RULES (Fishery Bulletin authors' checklist,
#          spo.nmfs.noaa.gov/sites/default/files/authorschecklist.pdf):
#   - Arial or Helvetica for labels inside the figure; no bold inside the
#     figure
#   - Multipart figures lettered A, B, C in bold Times New Roman, upper left
#   - No titles or captions in the figure; captions go in the manuscript
#   - Submit as pdf (preferred), at least 600 dpi; color only where the
#     figure cannot be read in black and white (editor decides)
#   - Fit one side of a standard page: figures here are 6.5 in wide or less
#
# OUTPUTS: each figure is written twice - .pdf for submission and a 600 dpi
#          .png for the working draft
# =============================================================================


theme_fishbull <- theme_classic(base_size = 9, base_family = "Helvetica") +
  theme(axis.text = element_text(color = "black", size = 8),
        axis.title = element_text(size = 9),
        axis.ticks = element_line(color = "black", linewidth = 0.3),
        axis.line = element_line(color = "black", linewidth = 0.3),
        legend.position = "bottom",
        legend.text = element_text(size = 8),
        legend.key.size = unit(0.8, "lines"),
        legend.margin = margin(0, 0, 0, 0),
        strip.background = element_blank(),
        strip.text = element_text(size = 8.5, hjust = 0, margin = margin(b = 3)),
        panel.spacing = unit(0.9, "lines"),
        plot.tag = element_text(family = "Times New Roman", face = "bold", size = 11),
        plot.tag.position = c(0, 1),
        plot.margin = margin(6, 8, 4, 4))

save_figure <- function(plot, name, width, height) {
  ggsave(here("outputs", paste0(name, ".pdf")), plot,
         width = width, height = height, device = cairo_pdf)
  ggsave(here("outputs", paste0(name, ".png")), plot,
         width = width, height = height, dpi = 600)
}

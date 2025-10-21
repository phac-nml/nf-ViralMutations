#!/usr/bin/env Rscript

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)

dat <- read_tsv(args[1], col_names = F)
names(dat) <- c("CHR", "Position", "Depth")
if (max(dat$Depth) > 0){
    p <- ggplot(dat, aes(Position, Depth)) +
        theme_minimal() +
        geom_vline(xintercept = seq(1, max(dat$Position), 5000), colour = "grey96") +
        geom_line() +
        scale_y_log10(limits = c(1, NA)) +
        labs(x = "Genome position", y = "Depth, log10-scale") +
        theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +
        facet_wrap(~CHR, scales = "free_x", ncol = 1)

    ggsave(paste0(args[2],"_depth.pdf"), p, width = 9, height = 6, useDingbats = F, device = "pdf")
}

quit()
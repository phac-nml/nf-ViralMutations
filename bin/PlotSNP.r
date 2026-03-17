#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
# args order: depth file, variants file, Name, GeneLocs file


GeneLocs <- TRUE

if(length(args) < 4 || args[4] == "" || is.na(args[4]))
    GeneLocs <- FALSE

library(tidyr)
library(dplyr)
library(tibble)
library(ggplot2)
library(stringr)
library(ggrepel)
library(readxl)


depth <- read.delim(args[1], header = F, sep = "\t")
names(depth) <- c("CHR", "Position", "Depth")
num_plots <- length(unique(dat$CHR))
plot_top  <- ceiling(log10(max(depth$Depth)))
variants <- read.delim(args[2], sep = "\t")
if (nrow(variants) == 0) quit(save = "no")
variants <- variants %>%
select(-Depth) %>%
inner_join(depth, by = c("Chromosome" = "CHR", "Position")) %>%
mutate(Count = Alt_Freq * plot_top,
        lower = qbeta(0.025, round(Alt_Freq * Depth), Depth - round(Alt_Freq * Depth)) * plot_top,
        upper = qbeta(0.975, round(Alt_Freq * Depth), Depth - round(Alt_Freq * Depth)) * plot_top) %>%
separate(Annotation, c(NA, NA, NA, "Gene", NA, NA, NA, NA, NA, "Nuc", "Prot", NA, NA, NA, NA), extra = "drop", sep = "\\|") %>%
mutate(Prot = if_else(str_detect(Prot, "p\\."), Prot, Nuc)) %>%
mutate(Prot = substr(Prot, 3, nchar(Prot))) %>%
mutate(Prot = paste0(Gene, ":", Prot, ", ", round(Alt_Freq, 3))) %>%
rename(CHR = Chromosome)

print(GeneLocs)

if(GeneLocs){
    locs <- read_excel(args[4]) %>%
    mutate(Center = (Start + Stop) / 2,
            Height = ((seq_len(n())) %% 2) * 0.25 + .25,
            low_Height = (Height - 0.2),
            mid_Height = (Height + low_Height) / 2)

    p <- ggplot(depth, aes(Position, log10(Depth))) +
        scale_y_continuous(limits = c(0, plot_top), sec.axis = sec_axis(trans = ~.*(100 / plot_top), name = "Frequency")) +
        theme_minimal() +
        geom_vline(xintercept = seq(1, max(depth$Position), 5000), colour = "grey96") +
        geom_rect(data = locs, inherit.aes = F, aes(xmin = Start, xmax = Stop,
                                                    ymin = low_Height, ymax = Height,
                                                    group = CDS_Name, fill = CDS_Name),
                    alpha = 0.3) +
        geom_text_repel(data = locs, inherit.aes = F, aes(x = Center, y = mid_Height, label = CDS_Name),
                        hjust = 0.5, vjust = 0.0, size = 1.8, min.segment.length = 0.1, force = 0.5) +
        geom_line(alpha = 0.4) +
        geom_vline(data = variants, aes(xintercept = Position), colour = "red", size = 0.2, alpha = 0.6) +
        geom_segment(data = variants, aes(x = Position, xend = Position, y = lower, yend = upper), size = 0.4, colour = "red") +
        geom_point(data = variants, aes(x = Position, y = Count), colour = "red", size = 0.4) +
        geom_text_repel(data = variants, aes(x = Position, y = Count, label = Prot), size = 2.2, max.overlaps = 20, direction = "both", force = 2) +
        #scale_y_log10() +
        labs(x = "Genome position", y = "Read count, log10") +
        guides(fill = F) +
        theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +
        facet_wrap(~CHR, scales = "free_x", ncol = 1)

    ggsave(paste0(args[3], "_variants.pdf"), p, width = 9, height = 5 + 2 * num_plots, useDingbats = F, device = "pdf")
    quit()
} else {
    p <- ggplot(depth, aes(Position, log10(Depth))) +
        scale_y_continuous(limits = c(0, plot_top), sec.axis = sec_axis(trans = ~.*(100 / plot_top), name = "Frequency")) +
        theme_minimal() +
        geom_vline(xintercept = seq(1, max(depth$Position), 5000), colour = "grey96") +
        geom_line(alpha = 0.4) +
        geom_vline(data = variants, aes(xintercept = Position), colour = "red", size = 0.2, alpha = 0.6) +
        geom_segment(data = variants, aes(x = Position, xend = Position, y = lower, yend = upper), size = 0.4, colour = "red") +
        geom_point(data = variants, aes(x = Position, y = Count), colour = "red", size = 0.4) +
        geom_text_repel(data = variants, aes(x = Position, y = Count, label = Prot), size = 2.2, max.overlaps = 20, direction = "both", force = 2) +
        #scale_y_log10() +
        labs(x = "Genome position", y = "Read count, log10") +
        guides(fill = F) +
        theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +
        facet_wrap(~CHR, scales = "free_x", ncol = 1)

    ggsave(paste0(args[3], "_variants.pdf"), p, width = 9, height = 5 + 2 * num_plots, useDingbats = F, device = "pdf")
    quit()
}

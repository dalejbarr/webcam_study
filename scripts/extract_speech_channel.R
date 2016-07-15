library("dplyr")
library("tidyr")
library("purrr")

extract_channel <- function(SessionID, Dir, Filename, Chan) {
  ifile <- paste0("response/", Dir, "/", Filename)
  ofile <- paste0("speech_coding/", Dir, "/", Filename)
  chan <- ifelse(Chan == "left", 1L, 2L)
  cmd <- paste0("sox ", ifile, " ", ofile, " remix ", chan)
  system(cmd)
}

itm <- readRDS("data_raw/itm_sets.rds") %>%
  filter(Name %in% c("Target", "Competitor")) %>%
  spread(Name, Resource) %>%
  mutate(TargComp = paste0(Target, " / ", Competitor)) %>%
  select(Series, TargComp)

con <- src_sqlite("data_raw/EESP4_Speaker.db")

sess <- tbl(con, "Session") %>%
  filter(SessionID < 998L)

conds <- tbl(con, "Item") %>%
  filter(TemplateID == 2L) %>%
  inner_join(tbl(con, "Resource"), "ItemCellID") %>%
  filter(Code == "LISTENING") %>%
  select(-Cell, -ResID, -TemplateID) %>% collect()

## determine addressee identity (orange/yellow) for each phase
## and thus which channel of the stereo file has the speech data
all_items <- sess %>%
  inner_join(tbl(con, "ListOrder") %>%
             filter(PhaseID <= 12L), "ListID") %>%
  inner_join(tbl(con, "Item"), "ItemCellID") %>%
  select(SessionID, ListID, ListOrderID, TemplateID,
         ItemCellID, PhaseID, OrderConstraint) %>%
  arrange(SessionID, PhaseID, OrderConstraint)

conds <- all_items %>%
  filter(TemplateID == 2L) %>%
  inner_join(tbl(con, "Resource"), "ItemCellID") %>%
  filter(Code == "LISTENING") %>%
  collect() %>%
  mutate(Addr = sub("^instr/(yellow|orange)\\.png$", "\\1", Data),
         Phase = ifelse(OrderConstraint == 1L, "train", "test")) %>%
  select(SessionID, Block = PhaseID, Phase, Addr,
         OC = OrderConstraint) %>% collect()

pinfo <- conds %>%
  select(-OC) %>%
  spread(Phase, Addr) %>%
  inner_join(conds %>% filter(OC != 1L) %>% select(-Addr, -Phase),
             c("SessionID", "Block"))

iinfo <- all_items %>%
  filter(TemplateID == 1L) %>%
  inner_join(tbl(con, "Resource") %>%
             filter(Code == "SFILE"), "ItemCellID") %>%
  select(SessionID, ItemCellID, PhaseID, OrderConstraint, Data) %>%
  collect() %>%
  rename(Block = PhaseID) %>%
  mutate(Item = sub("^([A-Z]{1}_.+)_.+", "\\1", Data)) %>%
  group_by(SessionID, Block, Item) %>%
  arrange(desc(OrderConstraint)) %>%
  slice(1L) %>% ungroup() %>%
  filter(substr(Item, 3, 6) != "conv")

files_todo <- pinfo %>%
  inner_join(iinfo, c("SessionID", "Block")) %>%
  mutate(Addr = ifelse(OrderConstraint < OC, train, test),
         Chan = ifelse(Addr == "yellow", "right", "left"),
         Dir = sprintf("s%07d", SessionID)) %>%
  select(SessionID, Dir, Filename = Data, Chan)

## create dirs as needed
files_todo %>%
  `[[`("Dir") %>% unique() %>%
  walk(function(x) paste0("mkdir -p speech_coding/", x) %>% system())

## extract relevant channel
invoke_rows(extract_channel, files_todo) %>% invisible()

ft2 <- files_todo %>%
  mutate(Series = ifelse(substr(Filename, 1, 1) %in% c("T", "Z"),
                as.integer(substr(Filename, 3, 4)), NA_integer_)) %>%
  left_join(itm, "Series") %>%
  select(Session = Dir, Filename, Series, TargComp) %>%
  write.csv(row.names = FALSE, file = "speech_coding/coding_template.csv")

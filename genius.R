library(dplyr)
library(ggplot2)
library(stringr)
library(tm)
library(SnowballC)
library(tidyr)
library(tidytext)
library(wordcloud)
library(plotly)
library(RColorBrewer)
library(colortools)

#  for ggplot
themeObject <- function() {
  return (theme(
    plot.subtitle = element_text(color="#666666"),
    plot.title = element_text(family="Verdana"),
    axis.text.x = element_text(family = "Verdana", size = 10),
    axis.text.y = element_text(family = "Verdana", size = 12)
  ))
}

geniusLyricsUnmodified <- read.csv('lyrics_with_dates.csv', stringsAsFactors = F)

str(geniusLyricsUnmodified)

# make appropriate changes to columns and clean lyrics scrapped from web. And remove Despacito. (NAFIG)
geniusLyrics <- geniusLyricsUnmodified %>%
  mutate(Views = as.numeric(str_remove_all(Views, pattern = 'M'))) %>%
  mutate(Release.Date = as.Date(Release.Date, format = '%B %d, %Y')) %>%
  mutate(Lyrics = str_remove_all(string = Lyrics, pattern = '\\s*\\([^\\)]+\\)')) %>%
  mutate(Lyrics = str_remove_all(string = Lyrics, pattern = '\\s*\\[[^\\]]+\\]')) %>%
  mutate(Lyrics = iconv(Lyrics, to = 'ASCII', sub = '')) %>%
  mutate(Lyrics = trimws(Lyrics)) %>%
  filter(Title != 'Despacito (Remix)') %>%
  mutate(Year = as.factor(format(Release.Date, '%Y'))) %>%
  mutate(Position = row_number())

# get TermDocumentMatrix to analyze most commonly used words.


lyricsByYears <- geniusLyrics %>%
  group_by(Year) %>%
  filter(Position == min(Position))%>%
  arrange(desc(Year)) %>%
  as.data.frame()


createComparisonCloud <- function(filtered,option=weightTf,setThresold=F){
  vs <- VectorSource(filtered$Lyrics)
  cp <- VCorpus(vs)
  tdm <- TermDocumentMatrix(cp, control = list(
    removePunctuation = T,
    stopwords = T,
    removeNumbers = T,
    weighting = option
  ))
  if(setThresold){
    print('enters')
    tdm <- removeSparseTerms(tdm,0.9999) 
  }
  inspect(tdm)
  lyricMatrix <-as.matrix(tdm)
  colnames(lyricMatrix) <- filtered$Year
  comparison.cloud(lyricMatrix, 
                   max.words = 200,
                   colors= wheel("steelblue", num = 12),
                   scale=c(1,0.5),
                   title.size=1)
}

#The comparison cloud for most frequent Words
createComparisonCloud(lyricsByYears)
#The comparison cloud for most important Words
createComparisonCloud(lyricsByYears,weightTfIdf,T)


visualizeTopNWords <- function(filtered,topNum){
  vs <- VectorSource(filtered$Lyrics)
  cp <- VCorpus(vs)
  
  tdm <- TermDocumentMatrix(cp, control = list(
    removePunctuation = T,
    stopwords = T,
    removeNumbers = T
  ))
  lyricsMatrix <- as.matrix(tdm)
  
  df_freq <- data.frame(terms=rownames(lyricsMatrix), 
                        freq=rowSums(lyricsMatrix), 
                        stringsAsFactors = F)
  
  
  top_num <- df_freq %>% 
    top_n(topNum, freq) %>%
    arrange(desc(freq))
  
  top_num %>%
    ggplot(aes(x=reorder(terms,freq),y = freq, fill=terms))+
    geom_bar(stat="identity")+
    labs(x="Words", y="Number of occurences", title="Number of words")+
    theme(legend.position = "none")
}

visualizeTopNWords(lyricsByYears,8)

compareOldestNewest <- function(filtered){
  oldestLyrics <- filtered %>% 
    filter(Year == min(Year))
  
  newestLyrics <- filtered %>%
    filter(Year == max(Year))

  lyricsForBoth <- c(oldestLyrics$Lyrics, newestLyrics$Lyrics)
  
  vs <- VectorSource(lyricsForBoth)
  cp <- VCorpus(vs)
  tdm <- TermDocumentMatrix(cp, control = list(
    removePunctuation = T,
    stopwords = T,
    removeNumbers = T
  ))
  inspect(tdm)
  lyricMatrix <-as.matrix(tdm)
  colnames(lyricMatrix) <- c(oldestLyrics$Year, newestLyrics$Year)
  print(colnames(lyricMatrix))
  set.seed(1)
  comparison.cloud(lyricMatrix, 
                   max.words = 100,
                   colors= wheel("steelblue", num = 12),
                   min.freq = 10,
                   scale=c(1,0.5),
                   title.size = 0.5)
}

compareOldestNewest(lyricsByYears)



# df_freqs<-c()
# for(i in 1:length(lyricsByYears$Lyrics)){
# 
#   vs <- VectorSource(lyricsByYears$Lyrics[i])
#   cp <- VCorpus(vs)
#   tdm <- TermDocumentMatrix(cp, control = list(
#     removePunctuation = T,
#     stopwords = T,
#     removeNumbers = T
#   ))
# 
#   lyricsMatrix <- as.matrix(tdm)
# 
#   df_freq <- data.frame(terms=rownames(lyricsMatrix),
#                         freq=rowSums(lyricsMatrix),
#                         stringsAsFactors = F)
#   df_freqs<-rbind(df_freqs, df_freq)
# }







stopwordsDf <- data.frame(word = stopwords('en'), stringsAsFactors = F)

# remove stop words from lyrics
geniusLyrics <- geniusLyrics %>%
  unnest_tokens(word, Lyrics) %>%
  anti_join(stopwordsDf, by = "word")

commonWordsByYear <- geniusLyrics %>%
  group_by(Year, word) %>%
  summarise(num_of_words = n()) %>%
  arrange(num_of_words, Year) %>%
  top_n(3, num_of_words) %>%
  filter(num_of_words > 20)

commonWordsByYear %>%
  ggplot(aes(x = word, y = num_of_words, fill = word)) +
  facet_grid(. ~ Year, scales = 'free_x') +
  geom_bar(stat = 'identity', position = 'dodge') +
  labs(x = "Words", y = "Frequency", title = "Most Common Words Per Year") + 
  themeObject() +
  theme(legend.position = "none")

# sentiments

# pos - neg
bingSentiment <- geniusLyrics %>%
  inner_join(get_sentiments("bing"), by = "word")

# weight
afinnSentiment <- geniusLyrics %>%
  inner_join(get_sentiments("afinn"), by = "word")

# other emotions

loughranSentiment <- geniusLyrics %>%
  inner_join(get_sentiments("loughran"), by = "word")

# sentiment over the course of a song
sentimentProgression <- function(title) {
  afinnSentiment %>%
    group_by(Title) %>%
    mutate(position = row_number()) %>%
    filter(Title == title) %>%
    mutate(best = word[which(value == max(value))[1]], worst = word[which(value == min(value))[1]]) %>%
    ggplot(aes(x = position, y = value, fill = value)) + 
    geom_bar(stat = "identity") + 
    geom_label(aes(label = ifelse((word == best | word == worst), word, NA)), na.rm = T) +
    scale_fill_gradient(low="blue", high="orange", guide = guide_colourbar(title = "Sentiment", barwidth = 0.5)) + 
    ylim(-5.5, 5.5) + 
    labs(x = "Progress", y = "Sentiment", subtitle = "Change Of Sentiment Throughout Song", title = title) +
    theme_bw() +
    themeObject()
}

# Mood Wheel for each song
moodWheel <- function(title) {
  afinnSentiment %>%
    filter(Title == title) %>%
    mutate(position = row_number()) %>%
    ggplot(aes(x = position, y = value, fill = value)) +
    geom_bar(stat = 'identity') +
    coord_polar(theta = "x") +
    scale_fill_gradient(low="blue", high="orange", guide = guide_colourbar(title = "Sentiment", barwidth = 0.5)) + 
    labs(y = "") +
    theme(axis.title.y = element_blank(), axis.ticks.y = element_blank(), axis.text.y = element_blank())
}

moodWheel("Rap God")

negativeAuthors <- afinnSentiment %>%
  group_by(Author) %>%
  summarise(overall_sentiment = sum(value)) %>%
  arrange(desc(overall_sentiment)) %>%
  slice(tail(row_number(), 5))

positiveAuthors <- afinnSentiment %>%
  group_by(Author) %>%
  summarise(overall_sentiment = sum(value)) %>%
  arrange(desc(overall_sentiment)) %>%
  top_n(5, overall_sentiment)

ggplot(negativeAuthors, aes(x = Author, y = overall_sentiment)) + geom_bar(stat = "identity")

# radar plots
em <- loughranSentiment %>%
  filter(Author == "Eminem") %>%
  group_by(Author, sentiment) %>%
  summarise(count = n())

plot_ly(
  type = 'scatterpolar',
  fill = 'toself'
) %>%
  add_trace(
    r = em$count,
    theta = em$sentiment,
    name = 'Group A'
  ) %>%
  layout(
    polar = list(
      radialaxis = list(
        visible = T,
        range = c(0,50)
      )
    )
  )
  
  

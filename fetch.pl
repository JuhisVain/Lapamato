use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(time sleep);
use String::Similarity;
use JSON;
use v5.22;

my ($artist, $album, $song) = ('', '', '');
GetOptions ('artist=s' => \$artist,
	    'album=s' => \$album,
	    'song=s' => \$song);

my $valid_artist;
my $valid_album;

# Will need to be changed with a conf if this thing to be used by non-finnish:
my $ytm_songs_block_id = qr/\\x22Kappaleet\\x22/;

#say get_yt_artist_playlist(get_yt_channel(join('+', (split / /,  $artist))));

#say "art: " . $artist . " alb: " . $album . " song: " . $song . "\ndone\n";
query_by_artist_album($artist, $album);

sub play {
  my @yt_tracks = @_;
  my $tracks_string = '';
  foreach (@yt_tracks) {
    $tracks_string .= '"https://music.youtube.com/watch?v=' . $_ . '" ';
  }
  system 'mpv ' . $tracks_string . '--ytdl --no-video';
}

sub get_yt_channel {
  my $whole_query =
    "curl \"https://music.youtube.com/search?q="
    . shift
    . "\" -A \"Mozilla/5.0 (X11; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0\"";
  my $res=`$whole_query 2>&1`;
  print "Searching youtube with \"$whole_query\"\n";
  my ($name, $channel) =
    ($res =~ m{musicResponsiveListItemFlexColumnRenderer.*?:\\x22(.+?)\\x22\\x7d\\x5d\\x7d,.*?browseId\\x22:\\x22(.+?)\\x22,\\x22browseEndpointContext});
  #  print $matches[0] . "\nand channel:\n" . $matches[1] . "\n"; #OK
  #print $name . "\nand channel:\n" . $channel . "\n"; #OK
  $channel;
}

sub get_yt_artist_playlist {
  my $link_to_channel = shift;
  my $whole_query = 'curl "https://music.youtube.com/channel/'
    . $link_to_channel
    . '" -A "Mozilla/5.0 (X11; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0"';
  say "Searching for playlist with " . $whole_query . "\n";
  my $res = `$whole_query 2>&1`;
  $res =~ m{$ytm_songs_block_id.*?browseId\\x22:\\x22VL(.*?)\\x22,};
  $1; # that should be the link string to use
  # https://music.youtube.com/playlist?list= !!!HERE!!!

}

sub query_by_artist_album {
  my $artist = shift;
  my $album = shift;

  my $artist_q = join '+', (split / /, $artist);

  my @tracks = get_track_listing($artist, $album);
  say "@tracks";

  play(tracks_to_yttracks($valid_artist,
			  sanitize_query_string($valid_album),
			  @tracks));
}

sub tracks_to_yttracks {
  my $artist = shift;
  my $album = shift;
  my @tracks = @_;
  #say "TtytT: Artist: " . $artist . " Album: " . $album . "\nTracks:\n" . @tracks . "\n";
  my @yt_tracks;
  foreach (@tracks) {
    push @yt_tracks, query_ytm($artist, $album, $_);
  }
  foreach (@yt_tracks) {say $_;}
  @yt_tracks;
}

sub sanitize_query_string {
  my $string = shift;
  $string =~ s/(\W|[0-9])+/ /igr;
}

sub sanitize_ytm_bs {
  # Will probably break if some string composed mainly of punctuation
  shift =~  s/(\\x[0-9a-f]{2}|(\W)+)/ /gr;
}

#Returns videoid:
sub query_ytm {
  my ($artist, $album, $song) = @_; # album has been sanitized
  say "query_ytm with $artist $album $song";
  my $query =
    "curl \"https://music.youtube.com/search?q="
    . join('+', (split /-| /,  $artist)) . "+"
    . join('+', (split / /,  $album)) . "+"
    . join('+', (split / /,  $song))
    . "\" -A \"Mozilla/5.0 (X11; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0\"";
  my $res=`$query 2>&1`;
  #$res =~ m{$ytm_songs_block_id.*?videoID\\x22:\\x22(.*?)\\x22}is;
  say "with query: $query";
  #$1;

#  open FIRST, '>', join('', (split / /,  $song));
 # say FIRST $res;
  #close FIRST;

  my @options = ($res =~ m{accessibilityData\\x22:\\x7b\\x22label\\x22:\\x22.{1,100}?
\\x22\\x7d\\x7d\\x7d\\x7d,\\x22contentPosition\\x22:\\x22
MUSIC_ITEM_THUMBNAIL_OVERLAY_CONTENT_POSITION_CENTERED\\x22,\\x22displayStyle\\x22:\\x22
MUSIC_ITEM_THUMBNAIL_OVERLAY_DISPLAY_STYLE_PERSISTENT\\x22\\x7d\\x7d,\\x22flexColumns\\x22:\\x5b\\x7b\\x22
musicResponsiveListItemFlexColumnRenderer\\x22:\\x7b\\x22text\\x22:\\x7b\\x22runs\\x22:\\x5b\\x7b\\x22text\\x22:\\x22
(.{1,100}?) # SONG NAME
\\x22,\\x22navigationEndpoint\\x22:\\x7b\\x22clickTrackingParams\\x22:\\x22.{1,100}?(?:\\x3d)+
\\x22,\\x22watchEndpoint\\x22:\\x7b\\x22videoId\\x22:\\x22
(.{5,20}?) # ID
\\x22,\\x22(?:playlistId\\x22:\\x22.{1,100}?\\x22,\\x22)?watchEndpointMusicSupportedConfigs\\x22:\\x7b\\x22
watchEndpointMusicConfig\\x22:\\x7b\\x22musicVideoType\\x22:\\x22
MUSIC_VIDEO_TYPE_(.{3}) # TYPE
\\x22\\x7d\\x7d\\x7d\\x7d\\x7d\\x5d\\x7d,\\x22displayPriority\\x22:\\x22
MUSIC_RESPONSIVE_LIST_ITEM_COLUMN_DISPLAY_PRIORITY_HIGH\\x22\\x7d\\x7d,\\x7b\\x22
musicResponsiveListItemFlexColumnRenderer\\x22:\\x7b\\x22text\\x22:\\x7b\\x22
runs\\x22:\\x5b\\x7b\\x22text\\x22:\\x22.{1,30}?
\\x22\\x7d,\\x7b\\x22text\\x22:\\x22.{3,10}? # some kind of dot unicode thing
\\x22\\x7d,\\x7b\\x22text\\x22:\\x22
(.{1,101}?) # BAND
\\x22,\\x22navigationEndpoint\\x22:\\x7b\\x22clickTrackingParams\\x22:\\x22.{1,50}?
\\x3d\\x22,\\x22browseEndpoint\\x22:\\x7b\\x22browseId\\x22:\\x22.{1,50}?\\x22,\\x22
browseEndpointContextSupportedConfigs\\x22:\\x7b\\x22browseEndpointContextMusicConfig
\\x22:\\x7b\\x22pageType\\x22:\\x22
MUSIC_PAGE_TYPE_ARTIST\\x22\\x7d\\x7d\\x7d\\x7d\\x7d,\\x7b\\x22text\\x22:\\x22.{3,10}? # some kind of dot again
\\x22\\x7d,\\x7b\\x22text\\x22:\\x22
(.{1,100}) # ALBUM
\\x22,\\x22navigationEndpoint\\x22:\\x7b\\x22clickTrackingParams}xgs);
  # song1, id1, type1, band1, album1, song2, id2, type2, band2, album2, etc...

  print "options length: " . @options . "\n";
  
  my $opti = 0;
  say "$song from album $album -> ";
  while ($options[$opti]) {
    say "---$options[$opti] -> " . similarity($song, $options[$opti]) . "     ID: $options[$opti+1] type: $options[$opti+2]";
    say "     " . sanitize_ytm_bs($options[$opti+4]) . " -> " . similarity($album, sanitize_ytm_bs($options[$opti+4]));
    $opti += 5;
  }
  
}

sub get_track_listing {
  state $last_call = 0;
  my $artist = shift;
  my $album = shift;
  until ((time - $last_call) > 1.1) {sleep 0.1;}
  $last_call = time;

  my $artist_q = join '%20', (split / /, $artist);
  my $album_q = join '%20', (split / /, $album);

  # search with artist & album:
  my $query =
    "curl \"http://musicbrainz.org/ws/2/release-group?fmt=json&query=artist:\"$artist_q\"ANDrelease:\"$album_q\"&offset=0&limit=10\" -s";
  my $art_rels = decode_json `$query 2>&1`;
  # get release ids:
  my $release_id = $art_rels->{"release-groups"}->[0]->{releases}->[0]->{id};

  ### While we're here, let's get the correct artist and album titles as well:
  $valid_artist = $art_rels->{"release-groups"}->[0]->{'artist-credit'}->[0]->{name};
  $valid_album = $art_rels->{"release-groups"}->[0]->{title};
  
  # get tracks for release0:
  until ((time - $last_call) > 1.1) {sleep 0.1;}
  $last_call = time;
  my $track_data = decode_json
    `curl \"http://musicbrainz.org/ws/2/release/$release_id?&inc=recordings&fmt=json\" -s 2>&1`;

  my $track_count = $track_data->{media}->[0]->{'track-count'};
  my @tracks;
  for (my $i=0; $i<$track_count; $i++) {
    $_ = $track_data->{media}->[0]->{tracks}->[$i];
    $tracks[$_->{position}-1] = $_->{title};
  }
  @tracks;
}

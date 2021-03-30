use strict;
use warnings;
use Getopt::Long;
use v5.22;

my ($artist, $album, $song) = ('', '', '');
GetOptions ('artist=s' => \$artist,
	    'album=s' => \$album,
	    'song=s' => \$song);

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
  my @aq_discogs_ids = get_discogs_ids($artist_q);
  my @aq_discogs_alb = get_discogs_album_ids($aq_discogs_ids[0], $album);

  my @tracks = get_track_listing($aq_discogs_alb[0]);
  say "1: " . $aq_discogs_ids[2] . " 2: " . $aq_discogs_alb[1] . " 3: " . $tracks[0] . "\ndone\n";

  play(tracks_to_yttracks($aq_discogs_ids[2],
			  sanitize_query_string($aq_discogs_alb[1]),
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
  $string =~ s/\W+/ /igr;
}

sub query_ytm {
  my ($artist, $album, $song) = @_;
  my $query =
    "curl \"https://music.youtube.com/search?q="
    . join('+', (split /-/,  $artist)) . "+"
    . join('+', (split / /,  $album)) . "+"
    . join('+', (split / /,  $song))
    . "\" -A \"Mozilla/5.0 (X11; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0\"";
  my $res=`$query 2>&1`;
  $res =~ m{$ytm_songs_block_id.*?videoID\\x22:\\x22(.*?)\\x22}is;
  #say $query . ' results in: ' . $1 . "\n";
  $1;
}

sub get_discogs_album_ids {
  #Takes strings artist, album. Returns (discogs_link_string1 album_name1 2 2 etc..).
  my $artist = shift;
  my $album = shift;
  my $artist_q = join '+', (split / /, $artist);
  my $album_q = join '+', (split / /, $album);
  my $query =
    "curl \"https://www.discogs.com/search/?limit=250&sort=score%2Cdesc&q="
    . $artist_q . "+" . $album_q
    . "&type=master&layout=sm\"";
  my $res=`$query 2>&1`;
  my @matches = ($res =~ m{<a class="search_result_title.*?href="(.*?)".*?>(.*?)</a>}sig);
}

sub get_track_listing {
  #Takes a discogs album link string. Returns list of strings: names of tracks on album.
  my $partial_album_link = shift;
  my $query =
    "curl \"https://www.discogs.com"
    . $partial_album_link
    . "\"";
  my $res=`$query 2>&1`;
#  open XXX, '>', "tracks.txt";
 # say XXX $res;
  #close XXX;
  $res =~ m{("tracks":.*?\])}si;
  #say "Found " . $res . "\n";
  my @tracks = ($1 =~ m{"name": "(.*?)"}sig);
  foreach (@tracks) {say $_;}
  @tracks;
}

sub get_discogs_ids {
  my $whole_query =
    "curl \"https://www.discogs.com/search/?limit=25&q="
    . shift
    . "&type=artist&layout=sm&page=1\"";
  #print "querying for \"$query_string\"\n   with query : $whole_query\n";
  my $res=`$whole_query 2>&1`; # curl outputs the useful stuff to STDERR
  my @matches = ($res =~ m{href="/artist/(([0-9]+)-([^/]*?))"}ig); # url-line1 ID1 name1 url-line2 ID2 name2 etc..
}

sub list_discogs_albums {
  my $whole_query =
    "curl \"https://www.discogs.com/artist/"
    . shift
    . "?sort=year%2Casc&limit=500&type=Releases&subtype=Albums&filter_anv=0&layout=sm&page=1\"";
  #print "\nAlbumquery is " . $whole_query . "\n\n";
  my $res=`$whole_query 2>&1`;
  my @album_list = ($res =~ m{<td class="artist"><a href=".*?">.*?</a>.*?<td class="title".*?(?:<span.*?</span>.*?)*<a href="(.*?)">(.*?)</a>.*?</td>}sig);
  # That's (link_to_album album_name) etc..
}





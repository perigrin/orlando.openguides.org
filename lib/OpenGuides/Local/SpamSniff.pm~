package OpenGuides::Local::SpamSniff;

use warnings;
use strict;

my $spam;
my @smells = <DATA>;

$spam = join '|', @smells;
$spam =~ s/\n//g;

sub looks_like_spam {
    my ($class, %args) = @_;

    if ($args{content} =~ /$spam/i) {
	warn "smells like sam";
        return 1;
    }

    # Link in title? Spam.
    if ($args{node} =~ /http|href/i) {
	warn "has link in title";
        return 1;
    }

    # 25 links or more? Most likely spam.
    my $links = (()= $args{content} =~ /http/ig));
    if (25 >= $links) {
    	warn "more than 25 links" .;
    	return 1; 
    }

    if ($args{metadata}{comment} =~ /Some grammatical corrections/) {
	"some grammatical corrections";
        return 1;
    }

    # everything is okay
    return 0;
}

1;

__DATA__
cialis(?!e)
viagra
vimax
penis
shemale
prepubescent
hentai
porno
felching
fisting
dildo

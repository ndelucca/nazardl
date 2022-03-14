#!/usr/bin/perl

use strict;
use warnings;

use feature qw( state say );

use utf8;
use open qw( :encoding(UTF-8) :std );
use autodie;

use Term::ANSIColor qw( colored );

sub conf {
    return {
        word_length => 5,
        max_attempts => 6,
        language => 'es_ES',
        cheat => 1,
    };
}

sub dictionaries {
    return {
        en_US => '/usr/share/dict/american-english',
        en_GB => '/usr/share/dict/british-english',
        es_ES => '/usr/share/dict/spanish',
    };
}

sub words {

    state @words = ();

    return @words if @words;

    my $lang = conf->{language};
    my $dict = dictionaries->{$lang};

    open( my $dict_fh, '<', $dict );

    while ( my $word = <$dict_fh>) {
        chomp $word;
        next if length $word != conf->{word_length};
        next if $word =~ /'/;

        # Mantengo o no las palabras con tilde?
        $word =~ tr/áéíóú/aeiou/;
        next if $word !~ /[[:alpha:]]/;
        push @words, lc $word;
    }

    close $dict_fh;

    return @words;
}

sub in_words($) {
    my $search = shift;
    for my $word ( words() ){
        return 1 if $word eq $search;
    }
    return;
}

sub chosen_word {
    state $word = random_word(words());
}

sub random_word {
    my @words = @_;
    my $index = rand(@words);
    return $words[$index];
}

sub handle_input {

    while (1) {
        my $input = lc <>;
        chomp($input);

        if ( length $input != conf->{word_length} ) {
            say 'You must choose a word of ' . conf->{word_length} . ' characters!';
        } elsif ( not in_words $input ) {
            say "That's not a valid word fella!";
        } else {
            return $input;
        }
    };
}

sub screen_clear {
    print "\033[2J";   # clear the screen
    print "\033[0;0H"; # jump to 0,0
}

sub screen_render_welcome {
    say "Welcome to NAZARDL.\n",
        'You must choose a ' . conf->{word_length} . " letter word.\n",
        'You have ' . attempts_left() . " attempts left";

}

sub color_attempt {
    my $attempt = shift;

    state %colors = (
        IN_PLACE => 'green',
        IN_WORD => 'yellow',
        UNUSED => 'white',
        USED => 'red',
    );

    my $out = '';

    for my $char_test ( @$attempt ) {
        my $color = $colors{$char_test->{state}};
        $out .= sprintf " %s ", colored($char_test->{char}, $color);
    }

    return $out;

}

sub screen_render_attempt {
    my $attempt = shift;

    say color_attempt($attempt), "\n";

}


sub screen_win_game {
    say 'Hurray! Almost flawless..';
}

sub screen_lose_game {
    say 'Better luck next time!';
}


{
    # Attempt handling

    my $left = conf->{max_attempts};

    sub use_attempt {
        $left--;
        return;
    }

    sub attempts_left {
        return $left;
    }
}


{
    # Tries handling

    my @tries = ();

    sub test_tries {
        return @tries;
    }

    sub test_successful {
        return 0 unless @tries;
        return $tries[-1]->{bullseye};
    }

    sub test_attempt {
        my $attempt = shift;

        my @attempts = ();
        my @chosen_chars = split //, chosen_word();

        my %chars_used;
        $chars_used{$_}++ for @chosen_chars;

        my @attempt_chars = split //, $attempt;
        my $attempt_status;

        while ( @chosen_chars ) {

            my $char_chosen = shift @chosen_chars;
            my $char_attempt = shift @attempt_chars;

            if ( $char_attempt eq $char_chosen ) {
                $chars_used{$char_attempt}--;
                $attempt_status = 'IN_PLACE';
            } elsif ( $chars_used{$char_attempt}) {
                $chars_used{$char_attempt}--;
                $attempt_status = 'IN_WORD';
            } else {
                $attempt_status = 'USED';
            }

            push @attempts, { char => $char_attempt, state => $attempt_status };

            set_alphabet_attempt($char_attempt, $attempt_status);
        }

        push @tries, {
            bullseye => chosen_word() eq $attempt,
            attempts => \@attempts
        };

        use_attempt();

        return;
    }

}

{

    my %alphabet = ();

    sub init_alphabet {

        for my $ord ( ord('a') .. ord('z') ){
            $alphabet{chr($ord)} = { char => chr($ord), state => 'UNUSED' };
        }

        return;

    }

    sub screen_render_alphabet{

        my @chars = sort { $a->{char} cmp $b->{char} } values %alphabet;
        my $attempts = join ' ', color_attempt( \@chars );

        say '';
        say '='x80;
        say '|' . $attempts . '|';
        say '='x80;
        say '';

    }

    sub set_alphabet_attempt {
        my $char = shift;
        my $status = shift;

        state %st = (
            IN_PLACE => 'IN_PLACE',
            IN_WORD => 'IN_WORD',
            USED => 'USED',
        );

        if ( $alphabet{$char}->{state} eq $st{IN_PLACE} || $status eq $st{IN_PLACE} ) {
            $alphabet{$char}->{state} = $st{IN_PLACE};
            return;
        } elsif ( $alphabet{$char}->{state} eq $st{IN_WORD} || $status eq $st{IN_WORD} ) {
            $alphabet{$char}->{state} = $st{IN_WORD};
            return;
        }

        $alphabet{$char}->{state} = $st{USED};
        return;
    }

}

sub main {

    init_alphabet();

    say chosen_word() if conf->{cheat};

    while (1) {

        screen_clear();
        screen_render_welcome();
        screen_render_alphabet();

        for my $test ( test_tries() ) {
            screen_render_attempt($test->{attempts});
        }

        if ( test_successful() ){
            screen_win_game();
            return;
        }

        if ( attempts_left() == 0 ) {
            screen_lose_game();
            return;
        }

        my $input = handle_input();

        # The end result prints on next iteration
        test_attempt( $input );

    };

    return;

}

# Runnner

main();
exit 0;

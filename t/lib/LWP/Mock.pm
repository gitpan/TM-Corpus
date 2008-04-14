package LWP::Mock;

sub new {
    return bless {}, shift;
}

sub get {
    my $self = shift;

    use HTTP::Response;
    use HTTP::Status;
    my $resp = HTTP::Response->new( HTTP::Status->RC_OK, "All well and good", undef, '<html />' );
    $resp->header ('Content-Type' => 'text/html' );
    return $resp;
}

1;

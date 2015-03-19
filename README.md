# Reference

This is part of a series of monthly Go challenges from which this is the first one.
For further reference look at http://golang-challenge.com

# How to compile/install/use

I decided to make it simple to compile so I avoid anyone having to install build tools and so on. Go has these tools built-in, but Erlangs approach is slightly different.

To compile the code, run an Erlang shell and ask it to compile (from the directory with this README file):

	$ erl
	1> c("src/decoder_dm.erl").
	ok
	2> decoder_dm:test().
	ok

The `priv` dir is an Erlang-convention where private data to a specific application is placed. It allows you to distribute, e.g., assets for a web page together with an application.

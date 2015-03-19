%%% @doc module decoder_dm defines a decoder for the drum machine
%%%
%%% The solution given here is in 43 lines of Erlang code. The code is somewhat idiomatic,
%%% though for a real-world implementation you would perhaps think more about the
%%% data representation and expand a bit here and there in order to make future extension
%%% easier.
%%%
%%% The challenge is easy to solve in Erlang because parsing binary telecom protocols is
%%% a common task in Erlang. Thus, the language has been extended with binary
%%% pattern matching capabilities to handle exactly these parsing tasks. I can simply describe
%%% the format recursively and the code will take apart the binary data structure one layer at
%%% at time.
%%% @end
-module(decoder_dm).

-export([
	p/1,
	render/1
]).

%% Only for testing. A real solution wouldn't have this included.
-export([test/0]).

%% p/1 is the main parser entrypoint.
%% Decode the header through binary pattern matching, use the instruments/1 parser
%% for the instruments. Construct an abstract syntax tree over the data.
p(<<"SPLICE", Len:64/integer, Payload:Len/binary, _Crap/binary>>) ->
  p_data(Payload).
  
p_data(<<HWString:32/binary, Tempo:32/float-little, Data/binary>>) ->
  Instruments = instruments(Data),
  #{ format => splice, hardware_string => trim_hwstring(HWString),
  	tempo => Tempo, instruments => Instruments }.

%% instruments/1 parses the instruments in the file.
%% Make good use of the binary pattern match capabilities of Erlang. Just parse by describing
%% the format in match position and deconstruct the binary scheme. Recurse on the remainder
%% of the file to gather up a list of the instruments.
%% Essentially we decode by a switch over the possible forms of instrument descriptions,
%% The last one, <<>> being the empty binary.
instruments(<<Num:8/integer, L:32/integer, Name:L/binary, Pattern:16/binary, Rest/binary>>) ->
    [{instrument, Num, Name, pattern(Pattern)} | instruments(Rest)];
instruments(<<>>) -> [].

%% pattern/1 decodes the rhythm pattern of the instrument
%% A rhythm section on the 808a and friends, is just 4 4byte values. For ease of
%% later working, we just decode them into lists which makes list comprehensions
%% work on the data.
pattern(<<P1:4/binary, P2:4/binary, P3:4/binary, P4:4/binary>>) ->
    [binary_to_list(P) || P <- [P1, P2, P3, P4]].


%% render/1 outputs the parsed file in the desired format
%% We use two tricks. First, we recurse by calling ourselves with a new pattern such
%% that every pattern is uniquely different. Second, we gather the data into an
%% iolist() type: a tree of data consisting of strings, binary data and lists. The iolist()
%% is tree like when constructed, but output functions automatically flatten them as
%% necessary.
%%
%% Essentially, this is a compiler from the AST into a Textual string representation:
render(#{ format := splice, tempo := Tempo, instruments := Instruments, hardware_string := HWS}) ->
    ["Saved with HW Version: ", HWS, $\n,
     render({tempo, Tempo}), $\n,
     render(Instruments)];
render(List) when is_list(List) ->
    [render(Elem) || Elem <- List];
render({tempo, T}) ->
    ["Tempo: ", format_float(T)];
render({instrument, N, Name, Pattern}) ->
    Prefix = io_lib:format("(~B) ~s\t", [N, Name]),
    Grid = render({pattern, Pattern}),
    [Prefix, Grid, $\n];
render({pattern, [P1, P2, P3, P4]}) ->
    [$|, conv(P1), $|, conv(P2), $|, conv(P3), $|, conv(P4), $|].
  
%% Rendering the pattern grid through use of list comprehensions
conv(Pat) -> [render_c(C) || C <- Pat].

render_c(0) -> $-;
render_c(1) -> $x.

%% Formatting of the tempo float.
%% It is not too neat since we have to decide if the number is close to 0 by checking
%% difference from a small ε.
format_float(F) ->
    case abs(F - trunc(F)) of
        K when K < 0.0001 -> integer_to_list(trunc(F));
        _ -> float_to_list(F, [{decimals, 1}, compact])
    end.

%% The Hardware string is 0-padded, so trim off the extra 0'es in the result.
trim_hwstring(B) ->
  Str = binary_to_list(B),
  string:strip(Str, right, 0).

%% Test helpers, which isn't really part of the solution

%% t/1 tests that a file renders to an expected output.
t({File, Expected}) ->
    {ok, Dat} = file:read_file("priv/fixtures/" ++ File),
    %% The following two lines uses an Erlang trick. The first line
    %% binds the Output to the rendered output. The second line
    %% then asserts this is the same as the expected data.
    %% if they don't match, the code will crash and we can handle that
    %% somewhere else.
    Output = iolist_to_binary(render(p(Dat))),
    Output = list_to_binary(Expected),
    ok.
    
test() ->
    lists:foreach(fun t/1, test_table()).

test_table() ->
	[{"pattern_1.splice",
	  "Saved with HW Version: 0.808-alpha\n"
      "Tempo: 120\n"
      "(0) kick	|x---|x---|x---|x---|\n"
      "(1) snare	|----|x---|----|x---|\n"
      "(2) clap	|----|x-x-|----|----|\n"
      "(3) hh-open	|--x-|--x-|x-x-|--x-|\n"
      "(4) hh-close	|x---|x---|----|x--x|\n"
      "(5) cowbell	|----|----|--x-|----|\n"},
     {"pattern_2.splice",
      "Saved with HW Version: 0.808-alpha\n"
      "Tempo: 98.4\n"
      "(0) kick	|x---|----|x---|----|\n"
      "(1) snare	|----|x---|----|x---|\n"
      "(3) hh-open	|--x-|--x-|x-x-|--x-|\n"
      "(5) cowbell	|----|----|x---|----|\n"},
     {"pattern_3.splice",
      "Saved with HW Version: 0.808-alpha\n"
      "Tempo: 118\n"
      "(40) kick	|x---|----|x---|----|\n"
      "(1) clap	|----|x---|----|x---|\n"
      "(3) hh-open	|--x-|--x-|x-x-|--x-|\n"
      "(5) low-tom	|----|---x|----|----|\n"
      "(12) mid-tom	|----|----|x---|----|\n"
      "(9) hi-tom	|----|----|-x--|----|\n"},
     {"pattern_4.splice",
      "Saved with HW Version: 0.909\n"
      "Tempo: 240\n"
      "(0) SubKick	|----|----|----|----|\n"
      "(1) Kick	|x---|----|x---|----|\n"
      "(99) Maracas	|x-x-|x-x-|x-x-|x-x-|\n"
      "(255) Low Conga	|----|x---|----|x---|\n"},
     {"pattern_5.splice",
      "Saved with HW Version: 0.708-alpha\n"
      "Tempo: 999\n"
      "(1) Kick	|x---|----|x---|----|\n"
      "(2) HiHat	|x-x-|x-x-|x-x-|x-x-|\n"}].

      

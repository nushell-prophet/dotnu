# Add the same text particle into the 'from' or 'to' column of the temp cyberlinks table
#
# > [[from_text, to_text]; ['cyber-prophet' null] ['tweet' 'cy is cool!']]
# | sort-by from_text | to yaml
# - from_text: cyber-prophet
#   to_text: master
#   from: QmXFUupJCSfydJZ85HQHD8tU1L7CZFErbRdMTBxkAmBJaD
#   to: QmZbcRTU4fdrMy2YzDKEUAXezF3pRDmFSMXbXYABVe3UhW
# - from_text: tweet
#   to_text: cy is cool!
#   from: QmbdH2WBamyKLPE5zu4mJ9v49qvY8BFfoumoVPMR5V4Rvx
#   to: QmddL5M8JZiaUDcEHT2LgUnZZGLMTTDEYVKWN1iMLk6PY8
#
# Some random example
# > ls
# | sort-by modified
# ; echo 'hello'
# hello
#
# Some random example
# > ls
# | sort-by modified;
# > echo 'hello'
# hello
#
# Some random example
# multiline
# > ls
# test
#
# Some random example multiline
# > ls
export def 'links-link-all' [] {}


# Some random example multiline 2
# > ls
export def 'links-link-all-2' [] {}

# no example provided
export def 'test' [] {}

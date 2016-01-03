# convert every word in the dictionary to be lower case
# and contain only characters a-z

from unidecode import unidecode
from sys import stdin, stdout

#d = stdin.read()
#index = d.index("clich")
#print [ord(d[i]) for i in xrange(index, index + 10)]

contents = unicode(stdin.read(), "latin_1")

contents = contents.split('--------------------------------------------------------------------')[1]

# get rid of accents and make everything lowercase
contents = unidecode(contents).lower()

processed = []
for c in contents:
    if (c >= 'a' and c <= 'z') or c == '\n':
        processed.append(c)
    elif c not in [' ', '-', '\'', '!', ',', '.', '?', '/', ';', ':']:
        raise Exception("unexpected: " + c + ',' + str(ord(c)))

stdout.write("".join(processed))

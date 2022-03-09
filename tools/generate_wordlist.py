import re

ucf = open("uncommon_words.txt", "r")
uncommon = ucf.readlines()
ucf.close()

cwf = open("common_words.txt", "r")
common = cwf.readlines()
cwf.close()

with open('../words.asm', 'w') as f:
    f.write("common_count:\n    dw %s\n" % len(common))
    f.write("word_count:\n    dw %s\n" % (len(common) + len(uncommon)))
    f.write("word_list:\n")
    for u in uncommon:
        f.write("    db \"%s\"\n" % u.replace("\n", ""))
    
    f.write("common_word_list:\n")
    for c in common:
        f.write("    db \"%s\"\n" % c.replace("\n", ""))

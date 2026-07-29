"""
Kandidaat-adressen in wijk Nieuwland (Amersfoort).

Bron: PDOK Locatieserver + BAG WFS.
Filter: gebruiksdoel=woonfunctie, oppervlakte>=80m², ≤3 VBO's per pand.


expected_has_charger=None omdat we hier geen ground truth
hebben — de scanner beoordeelt zelf en sorteert in by_verdict/.
"""

TEST_ADDRESSES = [
    {"adres": "Alpensalamander 4, Amersfoort", "lat": 52.1993115, "lng": 5.3678979, "expected_has_charger": None},  # 236m², 1vbo
    {"adres": "Alpensalamander 6, Amersfoort", "lat": 52.1993139, "lng": 5.3682014, "expected_has_charger": None},  # 184m², 1vbo
    {"adres": "Alpensalamander 8, Amersfoort", "lat": 52.1993156, "lng": 5.3683081, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Anna Boelensgaarde 1, Amersfoort", "lat": 52.1980034, "lng": 5.3739024, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Anna Boelensgaarde 2, Amersfoort", "lat": 52.1980644, "lng": 5.3739674, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 3, Amersfoort", "lat": 52.1981148, "lng": 5.3740290, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Anna Boelensgaarde 4, Amersfoort", "lat": 52.1981611, "lng": 5.3741145, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 5, Amersfoort", "lat": 52.1982032, "lng": 5.3742001, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Anna Boelensgaarde 6, Amersfoort", "lat": 52.1982411, "lng": 5.3742857, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Anna Boelensgaarde 7, Amersfoort", "lat": 52.1982726, "lng": 5.3743848, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Anna Boelensgaarde 8, Amersfoort", "lat": 52.1982999, "lng": 5.3744806, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Anna Boelensgaarde 9, Amersfoort", "lat": 52.1983315, "lng": 5.3746210, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 10, Amersfoort", "lat": 52.1983463, "lng": 5.3747304, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Anna Boelensgaarde 11, Amersfoort", "lat": 52.1983568, "lng": 5.3748400, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Anna Boelensgaarde 12, Amersfoort", "lat": 52.1983589, "lng": 5.3749460, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Anna Boelensgaarde 13, Amersfoort", "lat": 52.1983568, "lng": 5.3750624, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Anna Boelensgaarde 14, Amersfoort", "lat": 52.1983484, "lng": 5.3751583, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Anna Boelensgaarde 15, Amersfoort", "lat": 52.1983295, "lng": 5.3752712, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Anna Boelensgaarde 16, Amersfoort", "lat": 52.1983126, "lng": 5.3753772, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Anna Boelensgaarde 17, Amersfoort", "lat": 52.1982875, "lng": 5.3754730, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Anna Boelensgaarde 18, Amersfoort", "lat": 52.1982580, "lng": 5.3755724, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 19, Amersfoort", "lat": 52.1982222, "lng": 5.3756648, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Anna Boelensgaarde 20, Amersfoort", "lat": 52.1981761, "lng": 5.3757469, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 21, Amersfoort", "lat": 52.1981130, "lng": 5.3758564, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Anna Boelensgaarde 22, Amersfoort", "lat": 52.1980519, "lng": 5.3759283, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 23, Amersfoort", "lat": 52.1980015, "lng": 5.3759865, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Anna Boelensgaarde 24, Amersfoort", "lat": 52.1979405, "lng": 5.3760515, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Anna Boelensgaarde 25, Amersfoort", "lat": 52.1978796, "lng": 5.3760857, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 26, Amersfoort", "lat": 52.1978186, "lng": 5.3761268, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Anna Boelensgaarde 27, Amersfoort", "lat": 52.1977555, "lng": 5.3761542, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Anna Boelensgaarde 28, Amersfoort", "lat": 52.1976903, "lng": 5.3761851, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Barbarakruid 2, Amersfoort", "lat": 52.2011579, "lng": 5.3855442, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Barbarakruid 4, Amersfoort", "lat": 52.2011405, "lng": 5.3856403, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Barbarakruid 6, Amersfoort", "lat": 52.2011427, "lng": 5.3858429, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Barbarakruid 8, Amersfoort", "lat": 52.2011361, "lng": 5.3859638, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Barbarakruid 10, Amersfoort", "lat": 52.2011317, "lng": 5.3861664, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Barbarakruid 12, Amersfoort", "lat": 52.2011187, "lng": 5.3862767, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Barbarakruid 14, Amersfoort", "lat": 52.2011187, "lng": 5.3864830, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Barbarakruid 16, Amersfoort", "lat": 52.2011077, "lng": 5.3865824, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Barbarakruid 18, Amersfoort", "lat": 52.2011230, "lng": 5.3868421, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Barbarakruid 20, Amersfoort", "lat": 52.2011143, "lng": 5.3869452, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Barbarakruid 22, Amersfoort", "lat": 52.2011099, "lng": 5.3871550, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Barbarakruid 24, Amersfoort", "lat": 52.2010990, "lng": 5.3872581, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Barnsteenslak 1, Amersfoort", "lat": 52.2018700, "lng": 5.3709006, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Barnsteenslak 2, Amersfoort", "lat": 52.2019345, "lng": 5.3712679, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "Barnsteenslak 3, Amersfoort", "lat": 52.2019259, "lng": 5.3708795, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Barnsteenslak 4, Amersfoort", "lat": 52.2019841, "lng": 5.3712505, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "Barnsteenslak 5, Amersfoort", "lat": 52.2019646, "lng": 5.3708656, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Barnsteenslak 6, Amersfoort", "lat": 52.2020270, "lng": 5.3712294, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Barnsteenslak 7, Amersfoort", "lat": 52.2020140, "lng": 5.3708551, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Barnsteenslak 8, Amersfoort", "lat": 52.2020657, "lng": 5.3712083, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Barnsteenslak 9, Amersfoort", "lat": 52.2020528, "lng": 5.3708410, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Barnsteenslak 10, Amersfoort", "lat": 52.2021065, "lng": 5.3711768, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Barnsteenslak 11, Amersfoort", "lat": 52.2020936, "lng": 5.3708201, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Barnsteenslak 12, Amersfoort", "lat": 52.2021538, "lng": 5.3711454, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Barnsteenslak 13, Amersfoort", "lat": 52.2021430, "lng": 5.3708095, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Barnsteenslak 14, Amersfoort", "lat": 52.2021946, "lng": 5.3711209, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Barnsteenslak 15, Amersfoort", "lat": 52.2021904, "lng": 5.3707884, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Barnsteenslak 16, Amersfoort", "lat": 52.2022420, "lng": 5.3710823, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Barnsteenslak 17, Amersfoort", "lat": 52.2022355, "lng": 5.3707710, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Barnsteenslak 18, Amersfoort", "lat": 52.2022806, "lng": 5.3710614, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Barnsteenslak 19, Amersfoort", "lat": 52.2022849, "lng": 5.3707464, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Barnsteenslak 20, Amersfoort", "lat": 52.2023279, "lng": 5.3710369, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Barnsteenslak 21, Amersfoort", "lat": 52.2023215, "lng": 5.3707360, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Barnsteenslak 22, Amersfoort", "lat": 52.2023709, "lng": 5.3710158, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Barnsteenslak 23, Amersfoort", "lat": 52.2023687, "lng": 5.3707185, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Barnsteenslak 24, Amersfoort", "lat": 52.2024139, "lng": 5.3710018, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Barnsteenslak 25, Amersfoort", "lat": 52.2025214, "lng": 5.3707219, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Barnsteenslak 26, Amersfoort", "lat": 52.2025493, "lng": 5.3708793, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Bataafse Bellefleur 1, Amersfoort", "lat": 52.1952048, "lng": 5.3724982, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Bataafse Bellefleur 3, Amersfoort", "lat": 52.1952218, "lng": 5.3724179, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bataafse Bellefleur 5, Amersfoort", "lat": 52.1952332, "lng": 5.3723376, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bataafse Bellefleur 7, Amersfoort", "lat": 52.1952503, "lng": 5.3722636, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bataafse Bellefleur 9, Amersfoort", "lat": 52.1952655, "lng": 5.3721956, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bataafse Bellefleur 11, Amersfoort", "lat": 52.1952806, "lng": 5.3721061, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bataafse Bellefleur 13, Amersfoort", "lat": 52.1952939, "lng": 5.3720444, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bataafse Bellefleur 15, Amersfoort", "lat": 52.1953071, "lng": 5.3719611, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bataafse Bellefleur 17, Amersfoort", "lat": 52.1953166, "lng": 5.3718901, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Bellefleurgaarde 1, Amersfoort", "lat": 52.1954373, "lng": 5.3726024, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Bellefleurgaarde 2, Amersfoort", "lat": 52.1947135, "lng": 5.3715946, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Bellefleurgaarde 3, Amersfoort", "lat": 52.1954633, "lng": 5.3725102, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Bellefleurgaarde 4, Amersfoort", "lat": 52.1946994, "lng": 5.3716753, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 5, Amersfoort", "lat": 52.1954751, "lng": 5.3724448, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Bellefleurgaarde 6, Amersfoort", "lat": 52.1946852, "lng": 5.3717446, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Bellefleurgaarde 7, Amersfoort", "lat": 52.1954916, "lng": 5.3723677, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Bellefleurgaarde 8, Amersfoort", "lat": 52.1946686, "lng": 5.3718215, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 9, Amersfoort", "lat": 52.1955058, "lng": 5.3722946, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bellefleurgaarde 10, Amersfoort", "lat": 52.1946568, "lng": 5.3719024, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 11, Amersfoort", "lat": 52.1955177, "lng": 5.3722176, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Bellefleurgaarde 12, Amersfoort", "lat": 52.1946426, "lng": 5.3719754, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 13, Amersfoort", "lat": 52.1955342, "lng": 5.3721369, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Bellefleurgaarde 14, Amersfoort", "lat": 52.1946308, "lng": 5.3720525, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 15, Amersfoort", "lat": 52.1955484, "lng": 5.3720675, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Bellefleurgaarde 16, Amersfoort", "lat": 52.1946143, "lng": 5.3721256, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 17, Amersfoort", "lat": 52.1946333, "lng": 5.3735379, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Bellefleurgaarde 18, Amersfoort", "lat": 52.1946001, "lng": 5.3721988, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 19, Amersfoort", "lat": 52.1946925, "lng": 5.3735649, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 20, Amersfoort", "lat": 52.1945883, "lng": 5.3722719, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 21, Amersfoort", "lat": 52.1947587, "lng": 5.3735918, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Bellefleurgaarde 22, Amersfoort", "lat": 52.1945694, "lng": 5.3723642, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Bellefleurgaarde 23, Amersfoort", "lat": 52.1948060, "lng": 5.3736109, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Bellefleurgaarde 24, Amersfoort", "lat": 52.1945410, "lng": 5.3725374, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Bellefleurgaarde 25, Amersfoort", "lat": 52.1948723, "lng": 5.3736456, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Bellefleurgaarde 26, Amersfoort", "lat": 52.1945268, "lng": 5.3726105, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 27, Amersfoort", "lat": 52.1949290, "lng": 5.3736687, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 28, Amersfoort", "lat": 52.1945150, "lng": 5.3726952, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 29, Amersfoort", "lat": 52.1949952, "lng": 5.3737033, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Bellefleurgaarde 30, Amersfoort", "lat": 52.1945079, "lng": 5.3727645, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 31, Amersfoort", "lat": 52.1950425, "lng": 5.3737187, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "Bellefleurgaarde 32, Amersfoort", "lat": 52.1944961, "lng": 5.3728414, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 34, Amersfoort", "lat": 52.1944867, "lng": 5.3729222, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 36, Amersfoort", "lat": 52.1944748, "lng": 5.3729953, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 38, Amersfoort", "lat": 52.1944606, "lng": 5.3730724, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 40, Amersfoort", "lat": 52.1944512, "lng": 5.3731493, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 42, Amersfoort", "lat": 52.1944370, "lng": 5.3732185, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Bellefleurgaarde 44, Amersfoort", "lat": 52.1944252, "lng": 5.3733032, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 46, Amersfoort", "lat": 52.1944134, "lng": 5.3733803, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Bellefleurgaarde 48, Amersfoort", "lat": 52.1944086, "lng": 5.3734572, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Bellefleurgaarde 50, Amersfoort", "lat": 52.1943944, "lng": 5.3735457, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Bilzekruid 1, Amersfoort", "lat": 52.2014441, "lng": 5.3861487, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Bilzekruid 2, Amersfoort", "lat": 52.2014114, "lng": 5.3866749, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Bilzekruid 3, Amersfoort", "lat": 52.2014944, "lng": 5.3861309, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Bilzekruid 4, Amersfoort", "lat": 52.2014704, "lng": 5.3866642, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Bilzekruid 5, Amersfoort", "lat": 52.2016255, "lng": 5.3861557, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Bilzekruid 6, Amersfoort", "lat": 52.2016058, "lng": 5.3866856, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Bilzekruid 7, Amersfoort", "lat": 52.2016910, "lng": 5.3861415, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Bilzekruid 8, Amersfoort", "lat": 52.2016626, "lng": 5.3866714, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Bilzekruid 9, Amersfoort", "lat": 52.2018221, "lng": 5.3861701, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Bilzekruid 10, Amersfoort", "lat": 52.2017959, "lng": 5.3866856, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Bilzekruid 11, Amersfoort", "lat": 52.2018833, "lng": 5.3861487, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Bilzekruid 12, Amersfoort", "lat": 52.2018614, "lng": 5.3866714, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Bitterkruid 1, Amersfoort", "lat": 52.2008477, "lng": 5.3854554, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Bitterkruid 3, Amersfoort", "lat": 52.2008455, "lng": 5.3855585, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Bitterkruid 5, Amersfoort", "lat": 52.2008411, "lng": 5.3856580, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Bitterkruid 7, Amersfoort", "lat": 52.2008324, "lng": 5.3857611, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Bitterkruid 9, Amersfoort", "lat": 52.2008193, "lng": 5.3858749, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Bitterkruid 11, Amersfoort", "lat": 52.2007974, "lng": 5.3860705, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Bitterkruid 12, Amersfoort", "lat": 52.2007559, "lng": 5.3875888, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Bitterkruid 13, Amersfoort", "lat": 52.2007997, "lng": 5.3861558, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Bitterkruid 14, Amersfoort", "lat": 52.2008324, "lng": 5.3875781, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Bitterkruid 15, Amersfoort", "lat": 52.2007975, "lng": 5.3862660, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Bitterkruid 16, Amersfoort", "lat": 52.2008914, "lng": 5.3875781, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Bitterkruid 17, Amersfoort", "lat": 52.2007953, "lng": 5.3863727, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Bitterkruid 18, Amersfoort", "lat": 52.2009547, "lng": 5.3875888, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Bitterkruid 19, Amersfoort", "lat": 52.2007887, "lng": 5.3864651, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Bitterkruid 20, Amersfoort", "lat": 52.2010247, "lng": 5.3875817, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Bitterkruid 21, Amersfoort", "lat": 52.2007800, "lng": 5.3865931, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Bitterkruid 22, Amersfoort", "lat": 52.2010837, "lng": 5.3875817, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Bitterkruid 23, Amersfoort", "lat": 52.2007734, "lng": 5.3867673, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Bitterkruid 24, Amersfoort", "lat": 52.2011514, "lng": 5.3875852, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Bitterkruid 25, Amersfoort", "lat": 52.2007756, "lng": 5.3868741, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Bitterkruid 26, Amersfoort", "lat": 52.2012628, "lng": 5.3875745, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Bitterkruid 27, Amersfoort", "lat": 52.2007713, "lng": 5.3869843, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Bitterkruid 28, Amersfoort", "lat": 52.2013349, "lng": 5.3875817, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Bitterkruid 29, Amersfoort", "lat": 52.2007734, "lng": 5.3870909, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Bitterkruid 30, Amersfoort", "lat": 52.2014004, "lng": 5.3875852, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Bitterkruid 31, Amersfoort", "lat": 52.2007690, "lng": 5.3871977, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Bitterkruid 32, Amersfoort", "lat": 52.2014638, "lng": 5.3875923, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Bitterkruid 33, Amersfoort", "lat": 52.2012978, "lng": 5.3872012, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Bitterkruid 34, Amersfoort", "lat": 52.2015359, "lng": 5.3875995, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Bitterkruid 35, Amersfoort", "lat": 52.2013612, "lng": 5.3871798, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Bitterkruid 36, Amersfoort", "lat": 52.2016517, "lng": 5.3875995, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Bitterkruid 37, Amersfoort", "lat": 52.2014748, "lng": 5.3872012, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Bitterkruid 38, Amersfoort", "lat": 52.2017173, "lng": 5.3876030, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Bitterkruid 39, Amersfoort", "lat": 52.2015359, "lng": 5.3871870, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Bitterkruid 40, Amersfoort", "lat": 52.2017806, "lng": 5.3876065, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Bitterkruid 41, Amersfoort", "lat": 52.2016495, "lng": 5.3872190, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Bitterkruid 42, Amersfoort", "lat": 52.2018483, "lng": 5.3876137, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Bitterkruid 43, Amersfoort", "lat": 52.2017173, "lng": 5.3871977, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Bitterkruid 44, Amersfoort", "lat": 52.2019117, "lng": 5.3876244, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Bitterkruid 45, Amersfoort", "lat": 52.2018199, "lng": 5.3872261, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Bitterkruid 46, Amersfoort", "lat": 52.2020297, "lng": 5.3876279, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Bitterkruid 47, Amersfoort", "lat": 52.2018855, "lng": 5.3871977, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Bitterkruid 48, Amersfoort", "lat": 52.2020952, "lng": 5.3876351, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Bitterkruid 49, Amersfoort", "lat": 52.2020865, "lng": 5.3872616, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Bitterkruid 50, Amersfoort", "lat": 52.2021564, "lng": 5.3876386, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Bitterkruid 51, Amersfoort", "lat": 52.2020886, "lng": 5.3871443, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Bitterkruid 52, Amersfoort", "lat": 52.2022263, "lng": 5.3876457, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Bitterkruid 53, Amersfoort", "lat": 52.2020886, "lng": 5.3870305, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Bitterkruid 55, Amersfoort", "lat": 52.2020886, "lng": 5.3869274, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Bitterkruid 57, Amersfoort", "lat": 52.2020931, "lng": 5.3868314, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Bitterkruid 59, Amersfoort", "lat": 52.2020931, "lng": 5.3867176, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Bitterkruid 61, Amersfoort", "lat": 52.2020952, "lng": 5.3866110, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Bitterkruid 63, Amersfoort", "lat": 52.2020974, "lng": 5.3865150, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Blaasjeskruid 2, Amersfoort", "lat": 52.2013196, "lng": 5.3856154, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Blaasjeskruid 4, Amersfoort", "lat": 52.2013808, "lng": 5.3856011, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Blaasjeskruid 6, Amersfoort", "lat": 52.2014835, "lng": 5.3856261, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Blaasjeskruid 8, Amersfoort", "lat": 52.2015556, "lng": 5.3856047, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Blaasjeskruid 10, Amersfoort", "lat": 52.2016517, "lng": 5.3856296, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Blaasjeskruid 12, Amersfoort", "lat": 52.2017217, "lng": 5.3856154, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Blaasjeskruid 14, Amersfoort", "lat": 52.2018265, "lng": 5.3856366, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Blaasjeskruid 16, Amersfoort", "lat": 52.2018986, "lng": 5.3856189, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Blaasjeskruid 18, Amersfoort", "lat": 52.2021062, "lng": 5.3855371, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Blaasjeskruid 20, Amersfoort", "lat": 52.2021018, "lng": 5.3856402, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Blaasjeskruid 22, Amersfoort", "lat": 52.2020996, "lng": 5.3857541, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Blaasjeskruid 24, Amersfoort", "lat": 52.2020996, "lng": 5.3858572, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Blaasjeskruid 26, Amersfoort", "lat": 52.2020996, "lng": 5.3859602, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Blaasjeskruid 28, Amersfoort", "lat": 52.2020974, "lng": 5.3860633, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Blaasjeskruid 30, Amersfoort", "lat": 52.2020952, "lng": 5.3861664, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Blaasjeskruid 32, Amersfoort", "lat": 52.2020974, "lng": 5.3862767, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Blankvoorn 1, Amersfoort", "lat": 52.2050994, "lng": 5.3703427, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Blankvoorn 3, Amersfoort", "lat": 52.2050500, "lng": 5.3703326, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Blankvoorn 5, Amersfoort", "lat": 52.2050008, "lng": 5.3703227, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Blankvoorn 7, Amersfoort", "lat": 52.2049515, "lng": 5.3703126, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Blankvoorn 9, Amersfoort", "lat": 52.2049042, "lng": 5.3703126, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Blankvoorn 11, Amersfoort", "lat": 52.2048550, "lng": 5.3703027, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Blankvoorn 13, Amersfoort", "lat": 52.2048139, "lng": 5.3702926, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Blankvoorn 15, Amersfoort", "lat": 52.2047626, "lng": 5.3702793, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Brabantse Bellefleur 1, Amersfoort", "lat": 52.1949676, "lng": 5.3723933, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Brabantse Bellefleur 3, Amersfoort", "lat": 52.1949828, "lng": 5.3723130, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Brabantse Bellefleur 5, Amersfoort", "lat": 52.1949980, "lng": 5.3722359, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Brabantse Bellefleur 7, Amersfoort", "lat": 52.1950132, "lng": 5.3721587, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Brabantse Bellefleur 9, Amersfoort", "lat": 52.1950284, "lng": 5.3720847, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Brabantse Bellefleur 11, Amersfoort", "lat": 52.1950397, "lng": 5.3720136, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Brabantse Bellefleur 13, Amersfoort", "lat": 52.1950567, "lng": 5.3719335, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Brabantse Bellefleur 15, Amersfoort", "lat": 52.1950663, "lng": 5.3718531, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Brasem 2, Amersfoort", "lat": 52.2053540, "lng": 5.3706300, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Brasem 4, Amersfoort", "lat": 52.2053992, "lng": 5.3706735, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 6, Amersfoort", "lat": 52.2054382, "lng": 5.3707135, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 8, Amersfoort", "lat": 52.2054609, "lng": 5.3707971, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 10, Amersfoort", "lat": 52.2055204, "lng": 5.3708137, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 12, Amersfoort", "lat": 52.2055512, "lng": 5.3708605, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 14, Amersfoort", "lat": 52.2056025, "lng": 5.3708973, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 16, Amersfoort", "lat": 52.2056375, "lng": 5.3709374, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Brasem 18, Amersfoort", "lat": 52.2057771, "lng": 5.3710644, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Brasem 20, Amersfoort", "lat": 52.2058182, "lng": 5.3711177, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 22, Amersfoort", "lat": 52.2058613, "lng": 5.3711479, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 24, Amersfoort", "lat": 52.2059003, "lng": 5.3712014, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Brasem 26, Amersfoort", "lat": 52.2059496, "lng": 5.3712248, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 28, Amersfoort", "lat": 52.2059887, "lng": 5.3712615, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 30, Amersfoort", "lat": 52.2060317, "lng": 5.3712982, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Brasem 32, Amersfoort", "lat": 52.2060728, "lng": 5.3713283, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Brilkruid 1, Amersfoort", "lat": 52.2013371, "lng": 5.3831362, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Brilkruid 2, Amersfoort", "lat": 52.2010425, "lng": 5.3832936, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Brilkruid 3, Amersfoort", "lat": 52.2013431, "lng": 5.3832088, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Brilkruid 4, Amersfoort", "lat": 52.2010425, "lng": 5.3833663, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "Brilkruid 5, Amersfoort", "lat": 52.2013491, "lng": 5.3832887, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Brilkruid 6, Amersfoort", "lat": 52.2010395, "lng": 5.3834461, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "Brilkruid 7, Amersfoort", "lat": 52.2013535, "lng": 5.3833662, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Brilkruid 8, Amersfoort", "lat": 52.2010366, "lng": 5.3835237, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Brilkruid 9, Amersfoort", "lat": 52.2013595, "lng": 5.3834461, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Brilkruid 10, Amersfoort", "lat": 52.2010366, "lng": 5.3836060, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Brilkruid 11, Amersfoort", "lat": 52.2013639, "lng": 5.3835236, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Brilkruid 12, Amersfoort", "lat": 52.2010336, "lng": 5.3836884, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Brilkruid 13, Amersfoort", "lat": 52.2013699, "lng": 5.3836060, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Brilkruid 14, Amersfoort", "lat": 52.2010306, "lng": 5.3837634, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Brilkruid 15, Amersfoort", "lat": 52.2013743, "lng": 5.3836810, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Brilkruid 16, Amersfoort", "lat": 52.2010277, "lng": 5.3838433, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Brilkruid 17, Amersfoort", "lat": 52.2013818, "lng": 5.3837586, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Brilkruid 18, Amersfoort", "lat": 52.2010261, "lng": 5.3839160, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Brilkruid 19, Amersfoort", "lat": 52.2013848, "lng": 5.3838384, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Brilkruid 20, Amersfoort", "lat": 52.2010261, "lng": 5.3840008, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Brilkruid 21, Amersfoort", "lat": 52.2013907, "lng": 5.3839208, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Brilkruid 22, Amersfoort", "lat": 52.2010232, "lng": 5.3840734, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Brilkruid 23, Amersfoort", "lat": 52.2013967, "lng": 5.3839958, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Brilkruid 24, Amersfoort", "lat": 52.2010232, "lng": 5.3841582, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Brilkruid 25, Amersfoort", "lat": 52.2014026, "lng": 5.3840710, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Brilkruid 26, Amersfoort", "lat": 52.2010202, "lng": 5.3842429, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Brilkruid 27, Amersfoort", "lat": 52.2014071, "lng": 5.3841557, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Brilkruid 29, Amersfoort", "lat": 52.2014116, "lng": 5.3842332, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Brilkruid 31, Amersfoort", "lat": 52.2014190, "lng": 5.3843179, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Brilsalamander 2, Amersfoort", "lat": 52.1999178, "lng": 5.3679437, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Brilsalamander 4, Amersfoort", "lat": 52.1998495, "lng": 5.3680174, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Brilsalamander 6, Amersfoort", "lat": 52.1998339, "lng": 5.3681586, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Brilsalamander 8, Amersfoort", "lat": 52.1998416, "lng": 5.3682678, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Coelhorsterappelgaarde 1, Amersfoort", "lat": 52.1963106, "lng": 5.3741595, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Coelhorsterappelgaarde 2, Amersfoort", "lat": 52.1962581, "lng": 5.3746832, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Coelhorsterappelgaarde 3, Amersfoort", "lat": 52.1963674, "lng": 5.3742006, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Coelhorsterappelgaarde 4, Amersfoort", "lat": 52.1963086, "lng": 5.3746968, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Coelhorsterappelgaarde 5, Amersfoort", "lat": 52.1964200, "lng": 5.3742109, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Coelhorsterappelgaarde 6, Amersfoort", "lat": 52.1963612, "lng": 5.3747174, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Coelhorsterappelgaarde 7, Amersfoort", "lat": 52.1964704, "lng": 5.3742313, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Coelhorsterappelgaarde 8, Amersfoort", "lat": 52.1964053, "lng": 5.3747310, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Coelhorsterappelgaarde 9, Amersfoort", "lat": 52.1965188, "lng": 5.3742313, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Coelhorsterappelgaarde 10, Amersfoort", "lat": 52.1964579, "lng": 5.3747516, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Coelhorsterappelgaarde 11, Amersfoort", "lat": 52.1965714, "lng": 5.3742724, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Coelhorsterappelgaarde 12, Amersfoort", "lat": 52.1965083, "lng": 5.3747687, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Coelhorsterappelgaarde 13, Amersfoort", "lat": 52.1966197, "lng": 5.3742861, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Coelhorsterappelgaarde 14, Amersfoort", "lat": 52.1965589, "lng": 5.3747891, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Coelhorsterappelgaarde 15, Amersfoort", "lat": 52.1966723, "lng": 5.3742997, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Coelhorsterappelgaarde 16, Amersfoort", "lat": 52.1966093, "lng": 5.3748029, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Coelhorsterappelgaarde 17, Amersfoort", "lat": 52.1968574, "lng": 5.3743681, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Coelhorsterappelgaarde 18, Amersfoort", "lat": 52.1967943, "lng": 5.3748678, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Coelhorsterappelgaarde 19, Amersfoort", "lat": 52.1969100, "lng": 5.3743785, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Coelhorsterappelgaarde 20, Amersfoort", "lat": 52.1968469, "lng": 5.3748849, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Coelhorsterappelgaarde 21, Amersfoort", "lat": 52.1969605, "lng": 5.3743989, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Coelhorsterappelgaarde 22, Amersfoort", "lat": 52.1968974, "lng": 5.3749020, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Coelhorsterappelgaarde 23, Amersfoort", "lat": 52.1970131, "lng": 5.3744160, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Coelhorsterappelgaarde 24, Amersfoort", "lat": 52.1969458, "lng": 5.3749122, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Coelhorsterappelgaarde 25, Amersfoort", "lat": 52.1970656, "lng": 5.3744365, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Coelhorsterappelgaarde 26, Amersfoort", "lat": 52.1969984, "lng": 5.3749328, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Coelhorsterappelgaarde 27, Amersfoort", "lat": 52.1972380, "lng": 5.3744947, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Coelhorsterappelgaarde 28, Amersfoort", "lat": 52.1971771, "lng": 5.3750079, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Coelhorsterappelgaarde 29, Amersfoort", "lat": 52.1972885, "lng": 5.3745084, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Coelhorsterappelgaarde 30, Amersfoort", "lat": 52.1972255, "lng": 5.3750148, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Coelhorsterappelgaarde 31, Amersfoort", "lat": 52.1973390, "lng": 5.3745255, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Coelhorsterappelgaarde 32, Amersfoort", "lat": 52.1972802, "lng": 5.3750285, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Coelhorsterappelgaarde 33, Amersfoort", "lat": 52.1973894, "lng": 5.3745460, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Coelhorsterappelgaarde 34, Amersfoort", "lat": 52.1973285, "lng": 5.3750421, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Coelhorsterappelgaarde 35, Amersfoort", "lat": 52.1974420, "lng": 5.3745562, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Coelhorsterappelgaarde 36, Amersfoort", "lat": 52.1973748, "lng": 5.3750627, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Coelhorsterappelgaarde 37, Amersfoort", "lat": 52.1974883, "lng": 5.3745664, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Coelhorsterappelgaarde 38, Amersfoort", "lat": 52.1974252, "lng": 5.3750729, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Coelhorsterappelgaarde 39, Amersfoort", "lat": 52.1975388, "lng": 5.3745835, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Coelhorsterappelgaarde 40, Amersfoort", "lat": 52.1974736, "lng": 5.3750934, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Coelhorsterappelgaarde 41, Amersfoort", "lat": 52.1975914, "lng": 5.3746041, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Coelhorsterappelgaarde 42, Amersfoort", "lat": 52.1975262, "lng": 5.3751105, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Dalkruid 2, Amersfoort", "lat": 52.2016564, "lng": 5.3829104, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Dalkruid 4, Amersfoort", "lat": 52.2016621, "lng": 5.3829890, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Dalkruid 6, Amersfoort", "lat": 52.2016698, "lng": 5.3830677, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Dalkruid 8, Amersfoort", "lat": 52.2016776, "lng": 5.3831462, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Dalkruid 10, Amersfoort", "lat": 52.2016892, "lng": 5.3832217, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Dalkruid 12, Amersfoort", "lat": 52.2016950, "lng": 5.3832939, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Dalkruid 14, Amersfoort", "lat": 52.2017046, "lng": 5.3833788, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Dalkruid 16, Amersfoort", "lat": 52.2017124, "lng": 5.3834638, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Dalkruid 18, Amersfoort", "lat": 52.2017143, "lng": 5.3835298, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Dalkruid 20, Amersfoort", "lat": 52.2017240, "lng": 5.3836178, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Dalkruid 22, Amersfoort", "lat": 52.2017317, "lng": 5.3836964, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Dalkruid 24, Amersfoort", "lat": 52.2017413, "lng": 5.3837718, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Dalkruid 26, Amersfoort", "lat": 52.2017510, "lng": 5.3838473, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Dalkruid 28, Amersfoort", "lat": 52.2017606, "lng": 5.3839354, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Dalkruid 30, Amersfoort", "lat": 52.2017684, "lng": 5.3840046, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Dalkruid 32, Amersfoort", "lat": 52.2017800, "lng": 5.3840863, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Dalkruid 34, Amersfoort", "lat": 52.2017858, "lng": 5.3841649, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Dalkruid 36, Amersfoort", "lat": 52.2017916, "lng": 5.3842404, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Dalkruid 38, Amersfoort", "lat": 52.2017993, "lng": 5.3843189, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Bonte Koe 2, Amersfoort", "lat": 52.2001177, "lng": 5.3787921, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Bonte Koe 4, Amersfoort", "lat": 52.2000521, "lng": 5.3784757, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Drie Kazen 2, Amersfoort", "lat": 52.1999386, "lng": 5.3781378, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "De Drie Kazen 4, Amersfoort", "lat": 52.2000062, "lng": 5.3780498, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "De Drie Kazen 6, Amersfoort", "lat": 52.2000545, "lng": 5.3779744, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Drie Kazen 8, Amersfoort", "lat": 52.2001241, "lng": 5.3778801, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Drie Kazen 10, Amersfoort", "lat": 52.2001723, "lng": 5.3778014, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "De Dubbele Sleutel 1, Amersfoort", "lat": 52.2001099, "lng": 5.3784541, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 2, Amersfoort", "lat": 52.2001585, "lng": 5.3787618, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Dubbele Sleutel 3, Amersfoort", "lat": 52.2001502, "lng": 5.3784467, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 4, Amersfoort", "lat": 52.2002048, "lng": 5.3787401, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 5, Amersfoort", "lat": 52.2001856, "lng": 5.3784077, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 6, Amersfoort", "lat": 52.2002569, "lng": 5.3787249, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 7, Amersfoort", "lat": 52.2002383, "lng": 5.3783629, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 8, Amersfoort", "lat": 52.2003023, "lng": 5.3787188, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 9, Amersfoort", "lat": 52.2002737, "lng": 5.3783355, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 10, Amersfoort", "lat": 52.2003378, "lng": 5.3786970, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 11, Amersfoort", "lat": 52.2003104, "lng": 5.3782960, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 12, Amersfoort", "lat": 52.2003809, "lng": 5.3786823, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 13, Amersfoort", "lat": 52.2003491, "lng": 5.3782434, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Dubbele Sleutel 14, Amersfoort", "lat": 52.2004230, "lng": 5.3786714, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Gekroonde El 2, Amersfoort", "lat": 52.1951218, "lng": 5.3813293, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "De Gekroonde El 4, Amersfoort", "lat": 52.1951034, "lng": 5.3812504, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "De Gekroonde El 6, Amersfoort", "lat": 52.1950803, "lng": 5.3811679, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "De Gekroonde El 8, Amersfoort", "lat": 52.1950619, "lng": 5.3810966, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Gekroonde El 10, Amersfoort", "lat": 52.1950389, "lng": 5.3810177, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Gekroonde El 12, Amersfoort", "lat": 52.1950203, "lng": 5.3809503, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "De Gekroonde El 14, Amersfoort", "lat": 52.1949881, "lng": 5.3808490, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Gekroonde El 16, Amersfoort", "lat": 52.1949673, "lng": 5.3807701, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "De Gekroonde El 18, Amersfoort", "lat": 52.1949465, "lng": 5.3806988, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "De Gekroonde El 20, Amersfoort", "lat": 52.1949305, "lng": 5.3806201, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Gekroonde El 22, Amersfoort", "lat": 52.1949073, "lng": 5.3805413, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Gekroonde El 24, Amersfoort", "lat": 52.1948866, "lng": 5.3804662, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "De Gouden Ploeg 1, Amersfoort", "lat": 52.1961446, "lng": 5.3818040, "expected_has_charger": None},  # 95m², 1vbo
    {"adres": "De Gouden Ploeg 3, Amersfoort", "lat": 52.1961787, "lng": 5.3818706, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "De Gouden Ploeg 5, Amersfoort", "lat": 52.1962105, "lng": 5.3819260, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Gouden Ploeg 7, Amersfoort", "lat": 52.1962469, "lng": 5.3819778, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 9, Amersfoort", "lat": 52.1962764, "lng": 5.3820443, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 11, Amersfoort", "lat": 52.1963059, "lng": 5.3821036, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Gouden Ploeg 13, Amersfoort", "lat": 52.1963377, "lng": 5.3821590, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Gouden Ploeg 15, Amersfoort", "lat": 52.1963718, "lng": 5.3822107, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Gouden Ploeg 17, Amersfoort", "lat": 52.1964059, "lng": 5.3822773, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Gouden Ploeg 19, Amersfoort", "lat": 52.1964514, "lng": 5.3823143, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "De Gouden Ploeg 21, Amersfoort", "lat": 52.1964627, "lng": 5.3824104, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "De Gouden Ploeg 23, Amersfoort", "lat": 52.1964719, "lng": 5.3824917, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "De Gouden Ploeg 25, Amersfoort", "lat": 52.1964695, "lng": 5.3825694, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Gouden Ploeg 27, Amersfoort", "lat": 52.1964286, "lng": 5.3826323, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "De Gouden Ploeg 29, Amersfoort", "lat": 52.1963968, "lng": 5.3827099, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Gouden Ploeg 31, Amersfoort", "lat": 52.1965672, "lng": 5.3828578, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "De Gouden Ploeg 33, Amersfoort", "lat": 52.1966150, "lng": 5.3829021, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "De Gouden Ploeg 35, Amersfoort", "lat": 52.1966536, "lng": 5.3829318, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 37, Amersfoort", "lat": 52.1967036, "lng": 5.3829686, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Gouden Ploeg 39, Amersfoort", "lat": 52.1967445, "lng": 5.3829983, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "De Gouden Ploeg 41, Amersfoort", "lat": 52.1967877, "lng": 5.3830315, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Gouden Ploeg 43, Amersfoort", "lat": 52.1969854, "lng": 5.3829168, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "De Gouden Ploeg 45, Amersfoort", "lat": 52.1969809, "lng": 5.3829835, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Gouden Ploeg 47, Amersfoort", "lat": 52.1969740, "lng": 5.3830649, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Gouden Ploeg 49, Amersfoort", "lat": 52.1969694, "lng": 5.3831387, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "De Gouden Ploeg 51, Amersfoort", "lat": 52.1969626, "lng": 5.3832239, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "De Gouden Ploeg 53, Amersfoort", "lat": 52.1969491, "lng": 5.3833126, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "De Gouden Ploeg 55, Amersfoort", "lat": 52.1972786, "lng": 5.3833764, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 57, Amersfoort", "lat": 52.1972892, "lng": 5.3832886, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 59, Amersfoort", "lat": 52.1972944, "lng": 5.3831987, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Gouden Ploeg 61, Amersfoort", "lat": 52.1972997, "lng": 5.3831323, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Gouden Ploeg 63, Amersfoort", "lat": 52.1973036, "lng": 5.3830574, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Gouden Ploeg 65, Amersfoort", "lat": 52.1973062, "lng": 5.3829782, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 67, Amersfoort", "lat": 52.1975522, "lng": 5.3830274, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "De Gouden Ploeg 69, Amersfoort", "lat": 52.1975457, "lng": 5.3830938, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "De Gouden Ploeg 71, Amersfoort", "lat": 52.1975417, "lng": 5.3831793, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "De Gouden Ploeg 73, Amersfoort", "lat": 52.1975365, "lng": 5.3832651, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "De Gouden Ploeg 75, Amersfoort", "lat": 52.1975299, "lng": 5.3833357, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "De Gouden Ploeg 77, Amersfoort", "lat": 52.1975167, "lng": 5.3834299, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "De Gouden Ploeg 79, Amersfoort", "lat": 52.1978561, "lng": 5.3835070, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "De Gouden Ploeg 81, Amersfoort", "lat": 52.1978628, "lng": 5.3834170, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Gouden Ploeg 83, Amersfoort", "lat": 52.1978680, "lng": 5.3833292, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "De Gouden Ploeg 85, Amersfoort", "lat": 52.1978745, "lng": 5.3832500, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 87, Amersfoort", "lat": 52.1978824, "lng": 5.3831708, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 89, Amersfoort", "lat": 52.1978890, "lng": 5.3831044, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 92, Amersfoort", "lat": 52.1958684, "lng": 5.3826193, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "De Gouden Ploeg 94, Amersfoort", "lat": 52.1959176, "lng": 5.3826739, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "De Gouden Ploeg 96, Amersfoort", "lat": 52.1959578, "lng": 5.3827138, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 98, Amersfoort", "lat": 52.1960002, "lng": 5.3827537, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 100, Amersfoort", "lat": 52.1960404, "lng": 5.3828010, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Gouden Ploeg 102, Amersfoort", "lat": 52.1960805, "lng": 5.3828445, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Gouden Ploeg 104, Amersfoort", "lat": 52.1961230, "lng": 5.3828881, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Gouden Ploeg 106, Amersfoort", "lat": 52.1961609, "lng": 5.3829280, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 108, Amersfoort", "lat": 52.1962011, "lng": 5.3829753, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Gouden Ploeg 110, Amersfoort", "lat": 52.1962569, "lng": 5.3830371, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 112, Amersfoort", "lat": 52.1963060, "lng": 5.3830734, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 114, Amersfoort", "lat": 52.1963484, "lng": 5.3831097, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Gouden Ploeg 116, Amersfoort", "lat": 52.1963908, "lng": 5.3831388, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Gouden Ploeg 118, Amersfoort", "lat": 52.1964355, "lng": 5.3831787, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Gouden Ploeg 120, Amersfoort", "lat": 52.1964801, "lng": 5.3832259, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Gouden Ploeg 122, Amersfoort", "lat": 52.1965202, "lng": 5.3832587, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Gouden Ploeg 124, Amersfoort", "lat": 52.1965604, "lng": 5.3832986, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Gouden Ploeg 126, Amersfoort", "lat": 52.1966028, "lng": 5.3833312, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Gouden Ploeg 128, Amersfoort", "lat": 52.1966453, "lng": 5.3833640, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "De Gouden Ploeg 130, Amersfoort", "lat": 52.1967291, "lng": 5.3834830, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "De Gouden Ploeg 132, Amersfoort", "lat": 52.1967593, "lng": 5.3835533, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "De Gouden Ploeg 134, Amersfoort", "lat": 52.1967852, "lng": 5.3836077, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 136, Amersfoort", "lat": 52.1967582, "lng": 5.3837310, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Gouden Ploeg 138, Amersfoort", "lat": 52.1968392, "lng": 5.3837463, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 140, Amersfoort", "lat": 52.1968747, "lng": 5.3838235, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Gouden Ploeg 142, Amersfoort", "lat": 52.1981250, "lng": 5.3835637, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "De Gouden Ploeg 144, Amersfoort", "lat": 52.1981401, "lng": 5.3834724, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 146, Amersfoort", "lat": 52.1981445, "lng": 5.3834004, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Gouden Ploeg 148, Amersfoort", "lat": 52.1981520, "lng": 5.3833162, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Gouden Ploeg 150, Amersfoort", "lat": 52.1981606, "lng": 5.3832441, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "De Gouden Ploeg 152, Amersfoort", "lat": 52.1981671, "lng": 5.3831686, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Laatste Stuiver 1, Amersfoort", "lat": 52.1942698, "lng": 5.3779810, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "De Laatste Stuiver 2, Amersfoort", "lat": 52.1942811, "lng": 5.3780585, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "De Laatste Stuiver 3, Amersfoort", "lat": 52.1942902, "lng": 5.3781362, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "De Laatste Stuiver 4, Amersfoort", "lat": 52.1943038, "lng": 5.3782177, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "De Laatste Stuiver 5, Amersfoort", "lat": 52.1943152, "lng": 5.3782915, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Laatste Stuiver 6, Amersfoort", "lat": 52.1943266, "lng": 5.3783692, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Laatste Stuiver 7, Amersfoort", "lat": 52.1943403, "lng": 5.3784505, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Laatste Stuiver 8, Amersfoort", "lat": 52.1943516, "lng": 5.3785356, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Laatste Stuiver 9, Amersfoort", "lat": 52.1943629, "lng": 5.3786021, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Laatste Stuiver 10, Amersfoort", "lat": 52.1943766, "lng": 5.3786724, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Laatste Stuiver 11, Amersfoort", "lat": 52.1943902, "lng": 5.3787500, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Laatste Stuiver 12, Amersfoort", "lat": 52.1944038, "lng": 5.3788202, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "De Nieuwe Engel 1, Amersfoort", "lat": 52.1989183, "lng": 5.3825813, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "De Nieuwe Engel 3, Amersfoort", "lat": 52.1989827, "lng": 5.3825842, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "De Nieuwe Engel 5, Amersfoort", "lat": 52.1990310, "lng": 5.3825957, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 7, Amersfoort", "lat": 52.1990882, "lng": 5.3826104, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 9, Amersfoort", "lat": 52.1991420, "lng": 5.3826219, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 11, Amersfoort", "lat": 52.1991956, "lng": 5.3826307, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 13, Amersfoort", "lat": 52.1992493, "lng": 5.3826453, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Nieuwe Engel 15, Amersfoort", "lat": 52.1993387, "lng": 5.3826744, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "De Nieuwe Engel 17, Amersfoort", "lat": 52.1993978, "lng": 5.3826859, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 19, Amersfoort", "lat": 52.1994496, "lng": 5.3826918, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 21, Amersfoort", "lat": 52.1995087, "lng": 5.3827093, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 23, Amersfoort", "lat": 52.1995659, "lng": 5.3827267, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 25, Amersfoort", "lat": 52.1996143, "lng": 5.3827297, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Nieuwe Engel 27, Amersfoort", "lat": 52.1996983, "lng": 5.3827588, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "De Nieuwe Engel 29, Amersfoort", "lat": 52.1997592, "lng": 5.3827646, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 31, Amersfoort", "lat": 52.1998200, "lng": 5.3827791, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 33, Amersfoort", "lat": 52.1998737, "lng": 5.3827879, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Nieuwe Engel 35, Amersfoort", "lat": 52.1999309, "lng": 5.3827995, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "De Nieuwe Engel 37, Amersfoort", "lat": 52.1999811, "lng": 5.3828140, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "De Nieuwe Engel 39, Amersfoort", "lat": 52.2000383, "lng": 5.3828228, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "De Oude Grutmolen 1, Amersfoort", "lat": 52.1990264, "lng": 5.3820244, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "De Oude Grutmolen 2, Amersfoort", "lat": 52.1992849, "lng": 5.3820212, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 3, Amersfoort", "lat": 52.1990400, "lng": 5.3818874, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Oude Grutmolen 4, Amersfoort", "lat": 52.1992928, "lng": 5.3819352, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 5, Amersfoort", "lat": 52.1990479, "lng": 5.3817661, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "De Oude Grutmolen 6, Amersfoort", "lat": 52.1992987, "lng": 5.3818490, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "De Oude Grutmolen 7, Amersfoort", "lat": 52.1990557, "lng": 5.3816355, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Oude Grutmolen 8, Amersfoort", "lat": 52.1993045, "lng": 5.3817598, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 9, Amersfoort", "lat": 52.1990675, "lng": 5.3815110, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "De Oude Grutmolen 10, Amersfoort", "lat": 52.1993143, "lng": 5.3816736, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 11, Amersfoort", "lat": 52.1990812, "lng": 5.3813772, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "De Oude Grutmolen 12, Amersfoort", "lat": 52.1993555, "lng": 5.3816003, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "De Oude Grutmolen 13, Amersfoort", "lat": 52.1990890, "lng": 5.3812591, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "De Oude Grutmolen 14, Amersfoort", "lat": 52.1993692, "lng": 5.3814313, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 15, Amersfoort", "lat": 52.1991007, "lng": 5.3811221, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "De Oude Grutmolen 16, Amersfoort", "lat": 52.1993457, "lng": 5.3813229, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 17, Amersfoort", "lat": 52.1991105, "lng": 5.3810009, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "De Oude Grutmolen 18, Amersfoort", "lat": 52.1993555, "lng": 5.3812431, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 19, Amersfoort", "lat": 52.1991223, "lng": 5.3808670, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Oude Grutmolen 20, Amersfoort", "lat": 52.1993613, "lng": 5.3811507, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 22, Amersfoort", "lat": 52.1993672, "lng": 5.3810615, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Grutmolen 24, Amersfoort", "lat": 52.1993731, "lng": 5.3809850, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Oude Munt 1, Amersfoort", "lat": 52.1951150, "lng": 5.3768826, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "De Oude Munt 2, Amersfoort", "lat": 52.1951808, "lng": 5.3764352, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Oude Munt 3, Amersfoort", "lat": 52.1950627, "lng": 5.3768826, "expected_has_charger": None},  # 193m², 1vbo
    {"adres": "De Oude Munt 4, Amersfoort", "lat": 52.1951217, "lng": 5.3764536, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Oude Munt 5, Amersfoort", "lat": 52.1949581, "lng": 5.3768715, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "De Oude Munt 6, Amersfoort", "lat": 52.1950127, "lng": 5.3764537, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Oude Munt 7, Amersfoort", "lat": 52.1949059, "lng": 5.3768715, "expected_has_charger": None},  # 170m², 2vbo
    {"adres": "De Oude Munt 8, Amersfoort", "lat": 52.1949490, "lng": 5.3764537, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Oude Munt 9, Amersfoort", "lat": 52.1947968, "lng": 5.3768752, "expected_has_charger": None},  # 207m², 1vbo
    {"adres": "De Oude Munt 10, Amersfoort", "lat": 52.1948377, "lng": 5.3764537, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "De Oude Munt 11, Amersfoort", "lat": 52.1947422, "lng": 5.3768716, "expected_has_charger": None},  # 201m², 1vbo
    {"adres": "De Oude Munt 12, Amersfoort", "lat": 52.1947809, "lng": 5.3764575, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "De Oude Munt 13, Amersfoort", "lat": 52.1946377, "lng": 5.3768753, "expected_has_charger": None},  # 210m², 1vbo
    {"adres": "De Oude Munt 14, Amersfoort", "lat": 52.1946673, "lng": 5.3764501, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "De Oude Munt 15, Amersfoort", "lat": 52.1945787, "lng": 5.3768791, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "De Oude Munt 16, Amersfoort", "lat": 52.1946082, "lng": 5.3764465, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Oude Munt 17, Amersfoort", "lat": 52.1944719, "lng": 5.3768828, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "De Oude Munt 18, Amersfoort", "lat": 52.1944946, "lng": 5.3764095, "expected_has_charger": None},  # 183m², 1vbo
    {"adres": "De Oude Munt 19, Amersfoort", "lat": 52.1942901, "lng": 5.3768680, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "De Oude Munt 20, Amersfoort", "lat": 52.1944400, "lng": 5.3763761, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "De Oude Munt 21, Amersfoort", "lat": 52.1942947, "lng": 5.3769457, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 22, Amersfoort", "lat": 52.1943401, "lng": 5.3763207, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "De Oude Munt 23, Amersfoort", "lat": 52.1942969, "lng": 5.3770307, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 24, Amersfoort", "lat": 52.1942878, "lng": 5.3762985, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "De Oude Munt 25, Amersfoort", "lat": 52.1942992, "lng": 5.3771047, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Oude Munt 26, Amersfoort", "lat": 52.1942607, "lng": 5.3779034, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "De Oude Munt 27, Amersfoort", "lat": 52.1942969, "lng": 5.3771785, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "De Oude Munt 28, Amersfoort", "lat": 52.1946287, "lng": 5.3778477, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "De Oude Munt 29, Amersfoort", "lat": 52.1942947, "lng": 5.3772562, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "De Oude Munt 30, Amersfoort", "lat": 52.1946424, "lng": 5.3779292, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Oude Munt 31, Amersfoort", "lat": 52.1942924, "lng": 5.3773450, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 32, Amersfoort", "lat": 52.1946515, "lng": 5.3780105, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Oude Munt 33, Amersfoort", "lat": 52.1942947, "lng": 5.3774190, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 34, Amersfoort", "lat": 52.1946628, "lng": 5.3780770, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 35, Amersfoort", "lat": 52.1942925, "lng": 5.3774966, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Oude Munt 36, Amersfoort", "lat": 52.1946787, "lng": 5.3781583, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 37, Amersfoort", "lat": 52.1944879, "lng": 5.3774485, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "De Oude Munt 38, Amersfoort", "lat": 52.1946946, "lng": 5.3782324, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "De Oude Munt 39, Amersfoort", "lat": 52.1945356, "lng": 5.3774448, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Oude Munt 40, Amersfoort", "lat": 52.1947038, "lng": 5.3783062, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Oude Munt 41, Amersfoort", "lat": 52.1945810, "lng": 5.3774410, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Oude Munt 42, Amersfoort", "lat": 52.1947151, "lng": 5.3783839, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Oude Munt 43, Amersfoort", "lat": 52.1946310, "lng": 5.3774410, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Oude Munt 44, Amersfoort", "lat": 52.1947288, "lng": 5.3784615, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Oude Munt 45, Amersfoort", "lat": 52.1946787, "lng": 5.3774448, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Oude Munt 46, Amersfoort", "lat": 52.1947447, "lng": 5.3785392, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Oude Munt 47, Amersfoort", "lat": 52.1947287, "lng": 5.3774448, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Oude Munt 48, Amersfoort", "lat": 52.1947583, "lng": 5.3786021, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 49, Amersfoort", "lat": 52.1947764, "lng": 5.3774448, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Oude Munt 50, Amersfoort", "lat": 52.1947765, "lng": 5.3786982, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "De Oude Munt 51, Amersfoort", "lat": 52.1948218, "lng": 5.3774409, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Oude Munt 52, Amersfoort", "lat": 52.1944334, "lng": 5.3789017, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Oude Munt 53, Amersfoort", "lat": 52.1948718, "lng": 5.3774373, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Oude Munt 55, Amersfoort", "lat": 52.1949241, "lng": 5.3774152, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Oude Munt 57, Amersfoort", "lat": 52.1949763, "lng": 5.3774447, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "De Oude Munt 59, Amersfoort", "lat": 52.1950150, "lng": 5.3775038, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Oude Munt 61, Amersfoort", "lat": 52.1950468, "lng": 5.3775814, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Oude Munt 63, Amersfoort", "lat": 52.1950196, "lng": 5.3776850, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 65, Amersfoort", "lat": 52.1950173, "lng": 5.3777590, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Oude Munt 67, Amersfoort", "lat": 52.1950196, "lng": 5.3778329, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "De Oude Munt 69, Amersfoort", "lat": 52.1950173, "lng": 5.3779142, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Oude Munt 71, Amersfoort", "lat": 52.1950173, "lng": 5.3779918, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Oude Munt 73, Amersfoort", "lat": 52.1950196, "lng": 5.3780770, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "De Oude Munt 75, Amersfoort", "lat": 52.1950219, "lng": 5.3781953, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Oude Munt 77, Amersfoort", "lat": 52.1950241, "lng": 5.3782730, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Oude Munt 79, Amersfoort", "lat": 52.1950219, "lng": 5.3783543, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "De Oude Munt 81, Amersfoort", "lat": 52.1950196, "lng": 5.3784356, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "De Oude Munt 83, Amersfoort", "lat": 52.1950196, "lng": 5.3785059, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 85, Amersfoort", "lat": 52.1950219, "lng": 5.3785909, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Oude Munt 87, Amersfoort", "lat": 52.1950197, "lng": 5.3786722, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "De Oude Munt 89, Amersfoort", "lat": 52.1950219, "lng": 5.3787535, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Oude Munt 91, Amersfoort", "lat": 52.1950423, "lng": 5.3788312, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "De Oude Munt 93, Amersfoort", "lat": 52.1950242, "lng": 5.3789200, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "De Oude Munt 95, Amersfoort", "lat": 52.1949969, "lng": 5.3789792, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "De Oude Munt 97, Amersfoort", "lat": 52.1949605, "lng": 5.3790642, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Oude Munt 99, Amersfoort", "lat": 52.1948992, "lng": 5.3790494, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Oude Munt 101, Amersfoort", "lat": 52.1948584, "lng": 5.3790753, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "De Oude Munt 103, Amersfoort", "lat": 52.1948106, "lng": 5.3791085, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 105, Amersfoort", "lat": 52.1947742, "lng": 5.3791382, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "De Oude Munt 107, Amersfoort", "lat": 52.1947311, "lng": 5.3791641, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Oude Munt 109, Amersfoort", "lat": 52.1945493, "lng": 5.3792603, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "De Oude Munt 111, Amersfoort", "lat": 52.1945675, "lng": 5.3793416, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Oude Munt 113, Amersfoort", "lat": 52.1945879, "lng": 5.3794156, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Oude Munt 115, Amersfoort", "lat": 52.1946061, "lng": 5.3794821, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "De Rode Leeuw 1, Amersfoort", "lat": 52.1987163, "lng": 5.3820075, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Rode Leeuw 3, Amersfoort", "lat": 52.1987263, "lng": 5.3819261, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Rode Leeuw 5, Amersfoort", "lat": 52.1987280, "lng": 5.3818447, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Rode Leeuw 7, Amersfoort", "lat": 52.1987313, "lng": 5.3817606, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Rode Leeuw 9, Amersfoort", "lat": 52.1987379, "lng": 5.3816874, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Rode Leeuw 11, Amersfoort", "lat": 52.1987446, "lng": 5.3816114, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Rode Leeuw 13, Amersfoort", "lat": 52.1988079, "lng": 5.3804829, "expected_has_charger": None},  # 215m², 1vbo
    {"adres": "De Rode Leeuw 15, Amersfoort", "lat": 52.1988145, "lng": 5.3803580, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "De Rode Leeuw 17, Amersfoort", "lat": 52.1988179, "lng": 5.3802440, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "De Rode Leeuw 19, Amersfoort", "lat": 52.1988279, "lng": 5.3801465, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "De Rode Leeuw 21, Amersfoort", "lat": 52.1988312, "lng": 5.3800325, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "De Rode Leeuw 23, Amersfoort", "lat": 52.1988379, "lng": 5.3799348, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "De Rode Leeuw 25, Amersfoort", "lat": 52.1988545, "lng": 5.3798317, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "De Rode Leeuw 27, Amersfoort", "lat": 52.1988646, "lng": 5.3797178, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "De Rode Leeuw 29, Amersfoort", "lat": 52.1988812, "lng": 5.3796038, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "De Rode Leeuw 31, Amersfoort", "lat": 52.1988878, "lng": 5.3794899, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "De Rode Leeuw 33, Amersfoort", "lat": 52.1988946, "lng": 5.3793923, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "De Rode Leeuw 35, Amersfoort", "lat": 52.1988778, "lng": 5.3793054, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "De Rode Leeuw 37, Amersfoort", "lat": 52.1988445, "lng": 5.3792187, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "De Rode Leeuw 39, Amersfoort", "lat": 52.1988045, "lng": 5.3791427, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "De Rode Leeuw 41, Amersfoort", "lat": 52.1987578, "lng": 5.3790667, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "De Rode Leeuw 43, Amersfoort", "lat": 52.1987144, "lng": 5.3789799, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "De Rode Leeuw 45, Amersfoort", "lat": 52.1986678, "lng": 5.3788985, "expected_has_charger": None},  # 199m², 1vbo
    {"adres": "De Rode Leeuw 47, Amersfoort", "lat": 52.1986311, "lng": 5.3788226, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "De Rode Leeuw 49, Amersfoort", "lat": 52.1985878, "lng": 5.3787412, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "De Rode Leeuw 51, Amersfoort", "lat": 52.1985444, "lng": 5.3786707, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "De Rode Leeuw 53, Amersfoort", "lat": 52.1985078, "lng": 5.3785894, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "De Rode Leeuw 55, Amersfoort", "lat": 52.1983943, "lng": 5.3782692, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "De Vergulde Paarden 1, Amersfoort", "lat": 52.1971298, "lng": 5.3805314, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "De Vergulde Paarden 2, Amersfoort", "lat": 52.1969684, "lng": 5.3807707, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "De Vergulde Paarden 3, Amersfoort", "lat": 52.1971615, "lng": 5.3805877, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 4, Amersfoort", "lat": 52.1969972, "lng": 5.3808364, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 5, Amersfoort", "lat": 52.1971960, "lng": 5.3806487, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 6, Amersfoort", "lat": 52.1970231, "lng": 5.3808974, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 7, Amersfoort", "lat": 52.1972306, "lng": 5.3807097, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 8, Amersfoort", "lat": 52.1970548, "lng": 5.3809536, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 9, Amersfoort", "lat": 52.1972595, "lng": 5.3807707, "expected_has_charger": None},  # 92m², 1vbo
    {"adres": "De Vergulde Paarden 10, Amersfoort", "lat": 52.1970894, "lng": 5.3810145, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 11, Amersfoort", "lat": 52.1972883, "lng": 5.3808270, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "De Vergulde Paarden 12, Amersfoort", "lat": 52.1971240, "lng": 5.3810802, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 13, Amersfoort", "lat": 52.1973228, "lng": 5.3808927, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 14, Amersfoort", "lat": 52.1971499, "lng": 5.3811412, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 15, Amersfoort", "lat": 52.1973517, "lng": 5.3809442, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "De Vergulde Paarden 16, Amersfoort", "lat": 52.1971845, "lng": 5.3811975, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 17, Amersfoort", "lat": 52.1973806, "lng": 5.3810005, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 18, Amersfoort", "lat": 52.1972076, "lng": 5.3812444, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 19, Amersfoort", "lat": 52.1974180, "lng": 5.3810614, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 20, Amersfoort", "lat": 52.1972393, "lng": 5.3813101, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 21, Amersfoort", "lat": 52.1974468, "lng": 5.3811177, "expected_has_charger": None},  # 82m², 1vbo
    {"adres": "De Vergulde Paarden 22, Amersfoort", "lat": 52.1972739, "lng": 5.3813711, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 23, Amersfoort", "lat": 52.1974929, "lng": 5.3811552, "expected_has_charger": None},  # 82m², 1vbo
    {"adres": "De Vergulde Paarden 24, Amersfoort", "lat": 52.1972999, "lng": 5.3814319, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 25, Amersfoort", "lat": 52.1975449, "lng": 5.3811787, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 26, Amersfoort", "lat": 52.1973373, "lng": 5.3814929, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "De Vergulde Paarden 27, Amersfoort", "lat": 52.1975910, "lng": 5.3811881, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Paarden 28, Amersfoort", "lat": 52.1973691, "lng": 5.3815212, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "De Vergulde Paarden 29, Amersfoort", "lat": 52.1976342, "lng": 5.3811974, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "De Vergulde Paarden 30, Amersfoort", "lat": 52.1974152, "lng": 5.3815305, "expected_has_charger": None},  # 92m², 1vbo
    {"adres": "De Vergulde Paarden 31, Amersfoort", "lat": 52.1977004, "lng": 5.3812021, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Paarden 32, Amersfoort", "lat": 52.1974728, "lng": 5.3815352, "expected_has_charger": None},  # 92m², 1vbo
    {"adres": "De Vergulde Paarden 33, Amersfoort", "lat": 52.1977408, "lng": 5.3812115, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Vergulde Paarden 34, Amersfoort", "lat": 52.1975189, "lng": 5.3815492, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Vergulde Paarden 35, Amersfoort", "lat": 52.1977956, "lng": 5.3812208, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Paarden 36, Amersfoort", "lat": 52.1975650, "lng": 5.3815539, "expected_has_charger": None},  # 92m², 1vbo
    {"adres": "De Vergulde Paarden 37, Amersfoort", "lat": 52.1978408, "lng": 5.3812343, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Vergulde Paarden 39, Amersfoort", "lat": 52.1978858, "lng": 5.3812496, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Paarden 40, Amersfoort", "lat": 52.1976481, "lng": 5.3815834, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 41, Amersfoort", "lat": 52.1979354, "lng": 5.3812612, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Vergulde Paarden 42, Amersfoort", "lat": 52.1976942, "lng": 5.3815807, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 43, Amersfoort", "lat": 52.1979803, "lng": 5.3812688, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "De Vergulde Paarden 44, Amersfoort", "lat": 52.1977486, "lng": 5.3815922, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 45, Amersfoort", "lat": 52.1980324, "lng": 5.3812881, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Vergulde Paarden 46, Amersfoort", "lat": 52.1977959, "lng": 5.3816076, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 48, Amersfoort", "lat": 52.1978409, "lng": 5.3816191, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 50, Amersfoort", "lat": 52.1978905, "lng": 5.3816267, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 52, Amersfoort", "lat": 52.1979354, "lng": 5.3816422, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 54, Amersfoort", "lat": 52.1979874, "lng": 5.3816537, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 56, Amersfoort", "lat": 52.1980371, "lng": 5.3816691, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 57, Amersfoort", "lat": 52.1981743, "lng": 5.3811149, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "De Vergulde Paarden 58, Amersfoort", "lat": 52.1980868, "lng": 5.3816767, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 59, Amersfoort", "lat": 52.1981814, "lng": 5.3810340, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "De Vergulde Paarden 60, Amersfoort", "lat": 52.1981294, "lng": 5.3816844, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 61, Amersfoort", "lat": 52.1981885, "lng": 5.3809571, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Paarden 62, Amersfoort", "lat": 52.1981790, "lng": 5.3816960, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "De Vergulde Paarden 63, Amersfoort", "lat": 52.1981956, "lng": 5.3808801, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 64, Amersfoort", "lat": 52.1982263, "lng": 5.3816960, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Paarden 65, Amersfoort", "lat": 52.1982002, "lng": 5.3808032, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 67, Amersfoort", "lat": 52.1982073, "lng": 5.3807185, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "De Vergulde Paarden 69, Amersfoort", "lat": 52.1982098, "lng": 5.3806492, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "De Vergulde Paarden 71, Amersfoort", "lat": 52.1982192, "lng": 5.3804913, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "De Vergulde Paarden 73, Amersfoort", "lat": 52.1982263, "lng": 5.3804182, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Paarden 75, Amersfoort", "lat": 52.1982405, "lng": 5.3803375, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 76, Amersfoort", "lat": 52.1984604, "lng": 5.3804797, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "De Vergulde Paarden 77, Amersfoort", "lat": 52.1982428, "lng": 5.3802490, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 78, Amersfoort", "lat": 52.1984580, "lng": 5.3803912, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "De Vergulde Paarden 79, Amersfoort", "lat": 52.1982499, "lng": 5.3801758, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "De Vergulde Paarden 80, Amersfoort", "lat": 52.1984627, "lng": 5.3803143, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "De Vergulde Paarden 81, Amersfoort", "lat": 52.1982522, "lng": 5.3801065, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "De Vergulde Paarden 82, Amersfoort", "lat": 52.1984699, "lng": 5.3802374, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Paarden 83, Amersfoort", "lat": 52.1982641, "lng": 5.3800180, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "De Vergulde Paarden 84, Amersfoort", "lat": 52.1984769, "lng": 5.3801527, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Vergulde Paarden 85, Amersfoort", "lat": 52.1982735, "lng": 5.3799411, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Vergulde Paarden 86, Amersfoort", "lat": 52.1984887, "lng": 5.3800795, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 87, Amersfoort", "lat": 52.1982783, "lng": 5.3798564, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "De Vergulde Paarden 88, Amersfoort", "lat": 52.1984958, "lng": 5.3800140, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Paarden 90, Amersfoort", "lat": 52.1985006, "lng": 5.3799333, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Paarden 92, Amersfoort", "lat": 52.1985077, "lng": 5.3798524, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 94, Amersfoort", "lat": 52.1985124, "lng": 5.3797677, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Paarden 96, Amersfoort", "lat": 52.1985218, "lng": 5.3796946, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 98, Amersfoort", "lat": 52.1985478, "lng": 5.3796176, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "De Vergulde Paarden 100, Amersfoort", "lat": 52.1985242, "lng": 5.3794984, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "De Vergulde Paarden 101, Amersfoort", "lat": 52.1982191, "lng": 5.3795485, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "De Vergulde Paarden 102, Amersfoort", "lat": 52.1984746, "lng": 5.3794598, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Paarden 103, Amersfoort", "lat": 52.1981836, "lng": 5.3794869, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Paarden 104, Amersfoort", "lat": 52.1984462, "lng": 5.3794098, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Paarden 105, Amersfoort", "lat": 52.1981481, "lng": 5.3794253, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "De Vergulde Paarden 106, Amersfoort", "lat": 52.1984130, "lng": 5.3793522, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Paarden 107, Amersfoort", "lat": 52.1981174, "lng": 5.3793714, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Paarden 108, Amersfoort", "lat": 52.1983799, "lng": 5.3792906, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Vergulde Paarden 109, Amersfoort", "lat": 52.1980866, "lng": 5.3793098, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "De Vergulde Paarden 110, Amersfoort", "lat": 52.1983515, "lng": 5.3792328, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "De Vergulde Paarden 111, Amersfoort", "lat": 52.1980488, "lng": 5.3792367, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "De Vergulde Paarden 112, Amersfoort", "lat": 52.1983161, "lng": 5.3791751, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Paarden 114, Amersfoort", "lat": 52.1982877, "lng": 5.3791097, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Paarden 116, Amersfoort", "lat": 52.1982546, "lng": 5.3790519, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Paarden 118, Amersfoort", "lat": 52.1982238, "lng": 5.3789865, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Pauw 1, Amersfoort", "lat": 52.1970562, "lng": 5.3793542, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "De Vergulde Pauw 2, Amersfoort", "lat": 52.1968601, "lng": 5.3792369, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Pauw 3, Amersfoort", "lat": 52.1968227, "lng": 5.3791712, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Pauw 4, Amersfoort", "lat": 52.1967968, "lng": 5.3791196, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Pauw 5, Amersfoort", "lat": 52.1967622, "lng": 5.3790586, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "De Vergulde Pauw 6, Amersfoort", "lat": 52.1967362, "lng": 5.3789978, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "De Vergulde Pauw 7, Amersfoort", "lat": 52.1967103, "lng": 5.3789274, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "De Vergulde Pauw 8, Amersfoort", "lat": 52.1966929, "lng": 5.3788571, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "De Vergulde Pauw 9, Amersfoort", "lat": 52.1966728, "lng": 5.3787819, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "De Vergulde Pauw 10, Amersfoort", "lat": 52.1966613, "lng": 5.3787116, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "De Vergulde Pauw 11, Amersfoort", "lat": 52.1966497, "lng": 5.3786318, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "De Vergulde Pauw 12, Amersfoort", "lat": 52.1966468, "lng": 5.3785568, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "De Vergulde Pauw 13, Amersfoort", "lat": 52.1966439, "lng": 5.3784818, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "De Vergulde Pauw 14, Amersfoort", "lat": 52.1966439, "lng": 5.3783834, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Pauw 15, Amersfoort", "lat": 52.1966468, "lng": 5.3783177, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Pauw 16, Amersfoort", "lat": 52.1966410, "lng": 5.3782331, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Pauw 17, Amersfoort", "lat": 52.1967794, "lng": 5.3783551, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Vergulde Pauw 18, Amersfoort", "lat": 52.1968371, "lng": 5.3783504, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Vergulde Pauw 19, Amersfoort", "lat": 52.1968861, "lng": 5.3783504, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Vergulde Pauw 20, Amersfoort", "lat": 52.1969351, "lng": 5.3783551, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "De Vergulde Pauw 21, Amersfoort", "lat": 52.1969840, "lng": 5.3783691, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Vergulde Pauw 22, Amersfoort", "lat": 52.1970301, "lng": 5.3783879, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "De Vergulde Pauw 23, Amersfoort", "lat": 52.1970792, "lng": 5.3784114, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Vergulde Pauw 24, Amersfoort", "lat": 52.1971253, "lng": 5.3784441, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "De Vergulde Pauw 25, Amersfoort", "lat": 52.1971657, "lng": 5.3784817, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Vergulde Pauw 26, Amersfoort", "lat": 52.1972002, "lng": 5.3785333, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Vergulde Pauw 27, Amersfoort", "lat": 52.1972377, "lng": 5.3785754, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Vergulde Pauw 28, Amersfoort", "lat": 52.1972694, "lng": 5.3786411, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Vergulde Valk 1, Amersfoort", "lat": 52.1973214, "lng": 5.3798466, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "De Vergulde Valk 2, Amersfoort", "lat": 52.1973705, "lng": 5.3801890, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Valk 3, Amersfoort", "lat": 52.1974078, "lng": 5.3802547, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Valk 4, Amersfoort", "lat": 52.1974396, "lng": 5.3803156, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Valk 5, Amersfoort", "lat": 52.1974727, "lng": 5.3803719, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "De Vergulde Valk 6, Amersfoort", "lat": 52.1975102, "lng": 5.3804236, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "De Vergulde Valk 7, Amersfoort", "lat": 52.1975448, "lng": 5.3804751, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "De Vergulde Valk 8, Amersfoort", "lat": 52.1975852, "lng": 5.3805173, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "De Vergulde Valk 9, Amersfoort", "lat": 52.1976284, "lng": 5.3805549, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "De Vergulde Valk 10, Amersfoort", "lat": 52.1976745, "lng": 5.3805877, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "De Vergulde Valk 11, Amersfoort", "lat": 52.1977149, "lng": 5.3806157, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "De Vergulde Valk 12, Amersfoort", "lat": 52.1977667, "lng": 5.3806299, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "De Vergulde Valk 13, Amersfoort", "lat": 52.1978129, "lng": 5.3806393, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Valk 14, Amersfoort", "lat": 52.1978590, "lng": 5.3806533, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "De Vergulde Valk 15, Amersfoort", "lat": 52.1979080, "lng": 5.3806580, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "De Vergulde Valk 16, Amersfoort", "lat": 52.1979599, "lng": 5.3806720, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Vergulde Valk 17, Amersfoort", "lat": 52.1978993, "lng": 5.3804093, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Vergulde Valk 18, Amersfoort", "lat": 52.1979079, "lng": 5.3803485, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "De Vergulde Valk 19, Amersfoort", "lat": 52.1979138, "lng": 5.3802592, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "De Vergulde Valk 20, Amersfoort", "lat": 52.1979166, "lng": 5.3801842, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "De Vergulde Valk 21, Amersfoort", "lat": 52.1979166, "lng": 5.3801092, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "De Vergulde Valk 22, Amersfoort", "lat": 52.1979138, "lng": 5.3800295, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "De Vergulde Valk 23, Amersfoort", "lat": 52.1979079, "lng": 5.3799451, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "De Vergulde Valk 24, Amersfoort", "lat": 52.1978935, "lng": 5.3798747, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "De Vergulde Valk 25, Amersfoort", "lat": 52.1978734, "lng": 5.3797949, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "De Vergulde Valk 26, Amersfoort", "lat": 52.1978474, "lng": 5.3797245, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "De Vergulde Valk 27, Amersfoort", "lat": 52.1978157, "lng": 5.3796495, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "De Vergulde Valk 28, Amersfoort", "lat": 52.1977869, "lng": 5.3795979, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "De Vergulde Wagen 1, Amersfoort", "lat": 52.1964454, "lng": 5.3798334, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "De Vergulde Wagen 2, Amersfoort", "lat": 52.1966173, "lng": 5.3795865, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 3, Amersfoort", "lat": 52.1964130, "lng": 5.3797808, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 4, Amersfoort", "lat": 52.1965829, "lng": 5.3795239, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 5, Amersfoort", "lat": 52.1963867, "lng": 5.3797215, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 6, Amersfoort", "lat": 52.1965546, "lng": 5.3794746, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 7, Amersfoort", "lat": 52.1963482, "lng": 5.3796524, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 8, Amersfoort", "lat": 52.1965222, "lng": 5.3794088, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 9, Amersfoort", "lat": 52.1963199, "lng": 5.3795963, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 10, Amersfoort", "lat": 52.1964899, "lng": 5.3793496, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 11, Amersfoort", "lat": 52.1962835, "lng": 5.3795371, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 12, Amersfoort", "lat": 52.1964575, "lng": 5.3792936, "expected_has_charger": None},  # 91m², 1vbo
    {"adres": "De Vergulde Wagen 13, Amersfoort", "lat": 52.1962532, "lng": 5.3794813, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 14, Amersfoort", "lat": 52.1964271, "lng": 5.3792343, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 15, Amersfoort", "lat": 52.1962269, "lng": 5.3794252, "expected_has_charger": None},  # 92m², 1vbo
    {"adres": "De Vergulde Wagen 16, Amersfoort", "lat": 52.1963948, "lng": 5.3791783, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "De Vergulde Wagen 17, Amersfoort", "lat": 52.1961945, "lng": 5.3793760, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 18, Amersfoort", "lat": 52.1963644, "lng": 5.3791290, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 19, Amersfoort", "lat": 52.1961642, "lng": 5.3793134, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 20, Amersfoort", "lat": 52.1963320, "lng": 5.3790664, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 21, Amersfoort", "lat": 52.1961358, "lng": 5.3792508, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 22, Amersfoort", "lat": 52.1962956, "lng": 5.3790006, "expected_has_charger": None},  # 82m², 1vbo
    {"adres": "De Vergulde Wagen 23, Amersfoort", "lat": 52.1960974, "lng": 5.3791883, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 24, Amersfoort", "lat": 52.1962815, "lng": 5.3789249, "expected_has_charger": None},  # 82m², 1vbo
    {"adres": "De Vergulde Wagen 25, Amersfoort", "lat": 52.1960711, "lng": 5.3791389, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "De Vergulde Wagen 26, Amersfoort", "lat": 52.1962774, "lng": 5.3788427, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 27, Amersfoort", "lat": 52.1960549, "lng": 5.3790764, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "De Vergulde Wagen 28, Amersfoort", "lat": 52.1962815, "lng": 5.3787637, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 29, Amersfoort", "lat": 52.1960549, "lng": 5.3790007, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 30, Amersfoort", "lat": 52.1962794, "lng": 5.3786847, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "De Vergulde Wagen 31, Amersfoort", "lat": 52.1960529, "lng": 5.3789217, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 32, Amersfoort", "lat": 52.1962774, "lng": 5.3785990, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 33, Amersfoort", "lat": 52.1960489, "lng": 5.3788393, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 34, Amersfoort", "lat": 52.1962774, "lng": 5.3785134, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Wagen 35, Amersfoort", "lat": 52.1960489, "lng": 5.3787703, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 36, Amersfoort", "lat": 52.1962794, "lng": 5.3784313, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 38, Amersfoort", "lat": 52.1962774, "lng": 5.3783555, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 39, Amersfoort", "lat": 52.1960508, "lng": 5.3786222, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 40, Amersfoort", "lat": 52.1962794, "lng": 5.3782731, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 41, Amersfoort", "lat": 52.1960508, "lng": 5.3785398, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 42, Amersfoort", "lat": 52.1962774, "lng": 5.3781975, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Wagen 43, Amersfoort", "lat": 52.1960488, "lng": 5.3784608, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 44, Amersfoort", "lat": 52.1962774, "lng": 5.3781218, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Vergulde Wagen 45, Amersfoort", "lat": 52.1960488, "lng": 5.3783819, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 46, Amersfoort", "lat": 52.1962814, "lng": 5.3780428, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "De Vergulde Wagen 47, Amersfoort", "lat": 52.1960508, "lng": 5.3783029, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 49, Amersfoort", "lat": 52.1960539, "lng": 5.3782239, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 51, Amersfoort", "lat": 52.1960539, "lng": 5.3781449, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 53, Amersfoort", "lat": 52.1960519, "lng": 5.3780659, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 55, Amersfoort", "lat": 52.1960519, "lng": 5.3779804, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 57, Amersfoort", "lat": 52.1960498, "lng": 5.3779046, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 58, Amersfoort", "lat": 52.1963977, "lng": 5.3778485, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "De Vergulde Wagen 59, Amersfoort", "lat": 52.1960478, "lng": 5.3778256, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 60, Amersfoort", "lat": 52.1964503, "lng": 5.3778453, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Vergulde Wagen 61, Amersfoort", "lat": 52.1960498, "lng": 5.3777466, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "De Vergulde Wagen 62, Amersfoort", "lat": 52.1964988, "lng": 5.3778419, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 63, Amersfoort", "lat": 52.1960538, "lng": 5.3776743, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 64, Amersfoort", "lat": 52.1965454, "lng": 5.3778419, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "De Vergulde Wagen 65, Amersfoort", "lat": 52.1960518, "lng": 5.3776051, "expected_has_charger": None},  # 92m², 1vbo
    {"adres": "De Vergulde Wagen 66, Amersfoort", "lat": 52.1965959, "lng": 5.3778419, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 68, Amersfoort", "lat": 52.1966384, "lng": 5.3778453, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "De Vergulde Wagen 70, Amersfoort", "lat": 52.1967861, "lng": 5.3778353, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "De Vergulde Wagen 72, Amersfoort", "lat": 52.1968325, "lng": 5.3778353, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "De Vergulde Wagen 74, Amersfoort", "lat": 52.1968860, "lng": 5.3778344, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 75, Amersfoort", "lat": 52.1961337, "lng": 5.3774687, "expected_has_charger": None},  # 92m², 1vbo
    {"adres": "De Vergulde Wagen 76, Amersfoort", "lat": 52.1969350, "lng": 5.3778344, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 77, Amersfoort", "lat": 52.1961769, "lng": 5.3774687, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 78, Amersfoort", "lat": 52.1969811, "lng": 5.3778344, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 79, Amersfoort", "lat": 52.1962202, "lng": 5.3774640, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 80, Amersfoort", "lat": 52.1970272, "lng": 5.3778343, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 81, Amersfoort", "lat": 52.1962720, "lng": 5.3774593, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 82, Amersfoort", "lat": 52.1970792, "lng": 5.3778392, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 83, Amersfoort", "lat": 52.1963181, "lng": 5.3774593, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 84, Amersfoort", "lat": 52.1971310, "lng": 5.3778296, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 85, Amersfoort", "lat": 52.1963672, "lng": 5.3774546, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 86, Amersfoort", "lat": 52.1971743, "lng": 5.3778296, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 87, Amersfoort", "lat": 52.1964133, "lng": 5.3774593, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 89, Amersfoort", "lat": 52.1964594, "lng": 5.3774640, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "De Vergulde Wagen 91, Amersfoort", "lat": 52.1965055, "lng": 5.3774733, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 93, Amersfoort", "lat": 52.1970763, "lng": 5.3774638, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Wagen 95, Amersfoort", "lat": 52.1971224, "lng": 5.3774638, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 97, Amersfoort", "lat": 52.1971685, "lng": 5.3774545, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 99, Amersfoort", "lat": 52.1972175, "lng": 5.3774591, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "De Vergulde Wagen 100, Amersfoort", "lat": 52.1973616, "lng": 5.3779609, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 101, Amersfoort", "lat": 52.1972607, "lng": 5.3774591, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "De Vergulde Wagen 102, Amersfoort", "lat": 52.1973933, "lng": 5.3780266, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Vergulde Wagen 103, Amersfoort", "lat": 52.1973097, "lng": 5.3774591, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "De Vergulde Wagen 104, Amersfoort", "lat": 52.1974250, "lng": 5.3780782, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 105, Amersfoort", "lat": 52.1973587, "lng": 5.3774451, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "De Vergulde Wagen 106, Amersfoort", "lat": 52.1974539, "lng": 5.3781392, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 107, Amersfoort", "lat": 52.1974135, "lng": 5.3774591, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "De Vergulde Wagen 108, Amersfoort", "lat": 52.1974913, "lng": 5.3782096, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 109, Amersfoort", "lat": 52.1974480, "lng": 5.3775528, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Wagen 110, Amersfoort", "lat": 52.1975230, "lng": 5.3782659, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "De Vergulde Wagen 111, Amersfoort", "lat": 52.1974769, "lng": 5.3776045, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 113, Amersfoort", "lat": 52.1975115, "lng": 5.3776655, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 115, Amersfoort", "lat": 52.1975432, "lng": 5.3777218, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 117, Amersfoort", "lat": 52.1975749, "lng": 5.3777827, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 119, Amersfoort", "lat": 52.1976066, "lng": 5.3778484, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 121, Amersfoort", "lat": 52.1976354, "lng": 5.3779094, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "De Vergulde Wagen 123, Amersfoort", "lat": 52.1976672, "lng": 5.3779656, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vergulde Wagen 125, Amersfoort", "lat": 52.1977018, "lng": 5.3780219, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "De Vrije Vriend 1, Amersfoort", "lat": 52.1993026, "lng": 5.3821105, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "De Vrije Vriend 3, Amersfoort", "lat": 52.1994183, "lng": 5.3821200, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 5, Amersfoort", "lat": 52.1994672, "lng": 5.3821200, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 7, Amersfoort", "lat": 52.1995123, "lng": 5.3821360, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 9, Amersfoort", "lat": 52.1995573, "lng": 5.3821456, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 11, Amersfoort", "lat": 52.1996024, "lng": 5.3821551, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 13, Amersfoort", "lat": 52.1996474, "lng": 5.3821646, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 15, Amersfoort", "lat": 52.1996945, "lng": 5.3821806, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 17, Amersfoort", "lat": 52.1997396, "lng": 5.3821902, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 19, Amersfoort", "lat": 52.1997826, "lng": 5.3821965, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 21, Amersfoort", "lat": 52.1998316, "lng": 5.3822094, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 23, Amersfoort", "lat": 52.1998787, "lng": 5.3822253, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 25, Amersfoort", "lat": 52.2000393, "lng": 5.3822826, "expected_has_charger": None},  # 80m², 1vbo
    {"adres": "De Vrije Vriend 27, Amersfoort", "lat": 52.2000491, "lng": 5.3822156, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "De Vrije Vriend 29, Amersfoort", "lat": 52.2000550, "lng": 5.3821359, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 31, Amersfoort", "lat": 52.2000609, "lng": 5.3820658, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 33, Amersfoort", "lat": 52.2000687, "lng": 5.3819892, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 35, Amersfoort", "lat": 52.2000707, "lng": 5.3819127, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 37, Amersfoort", "lat": 52.2000789, "lng": 5.3818405, "expected_has_charger": None},  # 88m², 2vbo
    {"adres": "De Vrije Vriend 39, Amersfoort", "lat": 52.2000697, "lng": 5.3817558, "expected_has_charger": None},  # 88m², 2vbo
    {"adres": "De Vrije Vriend 41, Amersfoort", "lat": 52.2000981, "lng": 5.3815779, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 43, Amersfoort", "lat": 52.2001059, "lng": 5.3814949, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 45, Amersfoort", "lat": 52.2001157, "lng": 5.3814184, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 47, Amersfoort", "lat": 52.2001196, "lng": 5.3813484, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 49, Amersfoort", "lat": 52.2001216, "lng": 5.3812781, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 51, Amersfoort", "lat": 52.2001274, "lng": 5.3812049, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Vrije Vriend 53, Amersfoort", "lat": 52.2001333, "lng": 5.3811284, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "De Witte Zwaan 1, Amersfoort", "lat": 52.1991771, "lng": 5.3801878, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "De Witte Zwaan 2, Amersfoort", "lat": 52.1994377, "lng": 5.3801272, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 3, Amersfoort", "lat": 52.1991850, "lng": 5.3800538, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "De Witte Zwaan 4, Amersfoort", "lat": 52.1994456, "lng": 5.3800379, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 5, Amersfoort", "lat": 52.1991928, "lng": 5.3799327, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "De Witte Zwaan 6, Amersfoort", "lat": 52.1994534, "lng": 5.3799422, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 7, Amersfoort", "lat": 52.1992065, "lng": 5.3798052, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "De Witte Zwaan 8, Amersfoort", "lat": 52.1994632, "lng": 5.3798593, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 9, Amersfoort", "lat": 52.1992182, "lng": 5.3796776, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "De Witte Zwaan 10, Amersfoort", "lat": 52.1994710, "lng": 5.3797733, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 11, Amersfoort", "lat": 52.1992300, "lng": 5.3795501, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "De Witte Zwaan 12, Amersfoort", "lat": 52.1994828, "lng": 5.3796935, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 13, Amersfoort", "lat": 52.1992418, "lng": 5.3794288, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "De Witte Zwaan 14, Amersfoort", "lat": 52.1994867, "lng": 5.3796042, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 15, Amersfoort", "lat": 52.1992532, "lng": 5.3792979, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "De Witte Zwaan 16, Amersfoort", "lat": 52.1994965, "lng": 5.3795149, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 18, Amersfoort", "lat": 52.1995043, "lng": 5.3794257, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "De Witte Zwaan 19, Amersfoort", "lat": 52.1992535, "lng": 5.3790781, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "De Witte Zwaan 20, Amersfoort", "lat": 52.1995043, "lng": 5.3793396, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 21, Amersfoort", "lat": 52.2001567, "lng": 5.3791481, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "De Witte Zwaan 22, Amersfoort", "lat": 52.1996375, "lng": 5.3793587, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 23, Amersfoort", "lat": 52.2002292, "lng": 5.3791608, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Witte Zwaan 24, Amersfoort", "lat": 52.1996885, "lng": 5.3793746, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 25, Amersfoort", "lat": 52.2003095, "lng": 5.3791800, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Witte Zwaan 26, Amersfoort", "lat": 52.1997394, "lng": 5.3793841, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 27, Amersfoort", "lat": 52.2003820, "lng": 5.3791991, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "De Witte Zwaan 28, Amersfoort", "lat": 52.1997815, "lng": 5.3793938, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 30, Amersfoort", "lat": 52.1998266, "lng": 5.3794001, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 32, Amersfoort", "lat": 52.1998716, "lng": 5.3794097, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 34, Amersfoort", "lat": 52.1999171, "lng": 5.3794196, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "De Witte Zwaan 36, Amersfoort", "lat": 52.1999618, "lng": 5.3794287, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "De Witte Zwaan 38, Amersfoort", "lat": 52.2000049, "lng": 5.3794384, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 40, Amersfoort", "lat": 52.2000500, "lng": 5.3794479, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "De Witte Zwaan 42, Amersfoort", "lat": 52.2000950, "lng": 5.3794606, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "De Witte Zwaan 44, Amersfoort", "lat": 52.2002067, "lng": 5.3794861, "expected_has_charger": None},  # 193m², 1vbo
    {"adres": "Drentse Bellefleur 2, Amersfoort", "lat": 52.1954135, "lng": 5.3730537, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Drentse Bellefleur 4, Amersfoort", "lat": 52.1954021, "lng": 5.3731278, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Drentse Bellefleur 6, Amersfoort", "lat": 52.1953908, "lng": 5.3732081, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Drentse Bellefleur 8, Amersfoort", "lat": 52.1953794, "lng": 5.3732791, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Drentse Bellefleur 10, Amersfoort", "lat": 52.1953661, "lng": 5.3733531, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Drentse Bellefleur 12, Amersfoort", "lat": 52.1953548, "lng": 5.3734334, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Drentse Bellefleur 14, Amersfoort", "lat": 52.1953453, "lng": 5.3735106, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Drentse Bellefleur 16, Amersfoort", "lat": 52.1953282, "lng": 5.3735877, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Drentse Bellefleur 18, Amersfoort", "lat": 52.1953188, "lng": 5.3736649, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Drentse Bellefleur 20, Amersfoort", "lat": 52.1953074, "lng": 5.3737389, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Drentse Bellefleur 22, Amersfoort", "lat": 52.1952941, "lng": 5.3738192, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Drentse Bellefleur 24, Amersfoort", "lat": 52.1952827, "lng": 5.3738871, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Drentse Bellefleur 26, Amersfoort", "lat": 52.1952638, "lng": 5.3739735, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Dubbele Bellefleur 2, Amersfoort", "lat": 52.1951669, "lng": 5.3729458, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Dubbele Bellefleur 4, Amersfoort", "lat": 52.1951556, "lng": 5.3730167, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Dubbele Bellefleur 6, Amersfoort", "lat": 52.1951385, "lng": 5.3730970, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Dubbele Bellefleur 8, Amersfoort", "lat": 52.1951252, "lng": 5.3731741, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Dubbele Bellefleur 10, Amersfoort", "lat": 52.1951157, "lng": 5.3732514, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Dubbele Bellefleur 12, Amersfoort", "lat": 52.1951044, "lng": 5.3733254, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Dubbele Bellefleur 14, Amersfoort", "lat": 52.1950892, "lng": 5.3734057, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Duifkruid 1, Amersfoort", "lat": 52.2007058, "lng": 5.3833476, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Duifkruid 3, Amersfoort", "lat": 52.2007078, "lng": 5.3834229, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Duifkruid 5, Amersfoort", "lat": 52.2007039, "lng": 5.3835110, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Duifkruid 7, Amersfoort", "lat": 52.2006942, "lng": 5.3835834, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Duifkruid 9, Amersfoort", "lat": 52.2006866, "lng": 5.3836650, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Duifkruid 11, Amersfoort", "lat": 52.2006807, "lng": 5.3837405, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Duifkruid 13, Amersfoort", "lat": 52.2006769, "lng": 5.3838159, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Duifkruid 15, Amersfoort", "lat": 52.2006692, "lng": 5.3839009, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Duifkruid 17, Amersfoort", "lat": 52.2006618, "lng": 5.3839780, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Duifkruid 19, Amersfoort", "lat": 52.2006557, "lng": 5.3840550, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Duifkruid 21, Amersfoort", "lat": 52.2006441, "lng": 5.3841272, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Duifkruid 23, Amersfoort", "lat": 52.2006364, "lng": 5.3842153, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Duizendguldenkruid 1, Amersfoort", "lat": 52.2002750, "lng": 5.3828696, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Duizendguldenkruid 3, Amersfoort", "lat": 52.2003368, "lng": 5.3828728, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 5, Amersfoort", "lat": 52.2003928, "lng": 5.3828854, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Duizendguldenkruid 7, Amersfoort", "lat": 52.2004469, "lng": 5.3828854, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 9, Amersfoort", "lat": 52.2005107, "lng": 5.3828884, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 11, Amersfoort", "lat": 52.2005609, "lng": 5.3828884, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 13, Amersfoort", "lat": 52.2006189, "lng": 5.3828853, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Duizendguldenkruid 15, Amersfoort", "lat": 52.2006750, "lng": 5.3828916, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Duizendguldenkruid 17, Amersfoort", "lat": 52.2007426, "lng": 5.3828695, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Duizendguldenkruid 19, Amersfoort", "lat": 52.2007985, "lng": 5.3828507, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 21, Amersfoort", "lat": 52.2008546, "lng": 5.3828413, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 23, Amersfoort", "lat": 52.2009106, "lng": 5.3828287, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 25, Amersfoort", "lat": 52.2009647, "lng": 5.3827973, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 27, Amersfoort", "lat": 52.2010227, "lng": 5.3827753, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 29, Amersfoort", "lat": 52.2010729, "lng": 5.3827564, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Duizendguldenkruid 31, Amersfoort", "lat": 52.2011231, "lng": 5.3827406, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Duizendguldenkruid 33, Amersfoort", "lat": 52.2011908, "lng": 5.3826966, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 35, Amersfoort", "lat": 52.2012486, "lng": 5.3826589, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 37, Amersfoort", "lat": 52.2013028, "lng": 5.3826211, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 39, Amersfoort", "lat": 52.2013550, "lng": 5.3825834, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 41, Amersfoort", "lat": 52.2013994, "lng": 5.3825426, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 43, Amersfoort", "lat": 52.2014515, "lng": 5.3825048, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 45, Amersfoort", "lat": 52.2015017, "lng": 5.3824608, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 47, Amersfoort", "lat": 52.2015462, "lng": 5.3824230, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 49, Amersfoort", "lat": 52.2016041, "lng": 5.3823508, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Duizendguldenkruid 51, Amersfoort", "lat": 52.2016543, "lng": 5.3822972, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Duizendguldenkruid 53, Amersfoort", "lat": 52.2016969, "lng": 5.3822438, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Duizendguldenkruid 55, Amersfoort", "lat": 52.2017451, "lng": 5.3821935, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Duizendguldenkruid 57, Amersfoort", "lat": 52.2017915, "lng": 5.3821432, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 59, Amersfoort", "lat": 52.2018360, "lng": 5.3820866, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Duizendguldenkruid 61, Amersfoort", "lat": 52.2018804, "lng": 5.3820362, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Duizendguldenkruid 63, Amersfoort", "lat": 52.2019248, "lng": 5.3819922, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Eendenkroos 1, Amersfoort", "lat": 52.2055679, "lng": 5.3745520, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 3, Amersfoort", "lat": 52.2055679, "lng": 5.3744715, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 5, Amersfoort", "lat": 52.2055657, "lng": 5.3743806, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 7, Amersfoort", "lat": 52.2055721, "lng": 5.3743071, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 9, Amersfoort", "lat": 52.2055742, "lng": 5.3742407, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 11, Amersfoort", "lat": 52.2055764, "lng": 5.3741706, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 13, Amersfoort", "lat": 52.2055764, "lng": 5.3740902, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 15, Amersfoort", "lat": 52.2055850, "lng": 5.3740238, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 17, Amersfoort", "lat": 52.2055872, "lng": 5.3739468, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 19, Amersfoort", "lat": 52.2056064, "lng": 5.3736074, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Eendenkroos 21, Amersfoort", "lat": 52.2056043, "lng": 5.3735338, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Eendenkroos 23, Amersfoort", "lat": 52.2056150, "lng": 5.3734569, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Eendenkroos 25, Amersfoort", "lat": 52.2056194, "lng": 5.3733764, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 27, Amersfoort", "lat": 52.2056215, "lng": 5.3733100, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 29, Amersfoort", "lat": 52.2056279, "lng": 5.3732330, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 31, Amersfoort", "lat": 52.2056322, "lng": 5.3731491, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Eendenkroos 33, Amersfoort", "lat": 52.2056343, "lng": 5.3730825, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Eendenkroos 35, Amersfoort", "lat": 52.2056322, "lng": 5.3730091, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Eendenkroos 37, Amersfoort", "lat": 52.2056515, "lng": 5.3728411, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 39, Amersfoort", "lat": 52.2056558, "lng": 5.3727851, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 41, Amersfoort", "lat": 52.2056601, "lng": 5.3727011, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Eendenkroos 43, Amersfoort", "lat": 52.2056601, "lng": 5.3726382, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Eendenkroos 45, Amersfoort", "lat": 52.2056665, "lng": 5.3725507, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Fanny Blankers-Koenpad 1, Amersfoort", "lat": 52.1956631, "lng": 5.3858175, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Fanny Blankers-Koenpad 3, Amersfoort", "lat": 52.1956631, "lng": 5.3858966, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Fanny Blankers-Koenpad 5, Amersfoort", "lat": 52.1956631, "lng": 5.3859755, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Fonteinkruid 2, Amersfoort", "lat": 52.2016834, "lng": 5.3817219, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Fonteinkruid 4, Amersfoort", "lat": 52.2011405, "lng": 5.3821402, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Fonteinkruid 6, Amersfoort", "lat": 52.2010690, "lng": 5.3822094, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Fonteinkruid 8, Amersfoort", "lat": 52.2009840, "lng": 5.3822502, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Fonteinkruid 10, Amersfoort", "lat": 52.2008990, "lng": 5.3822879, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Fonteinkruid 12, Amersfoort", "lat": 52.2008140, "lng": 5.3823194, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Fonteinkruid 14, Amersfoort", "lat": 52.2007328, "lng": 5.3823351, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Fonteinkruid 16, Amersfoort", "lat": 52.2006402, "lng": 5.3823509, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Forel 5, Amersfoort", "lat": 52.2015770, "lng": 5.3664404, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Forel 7, Amersfoort", "lat": 52.2016222, "lng": 5.3664237, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Forel 9, Amersfoort", "lat": 52.2016674, "lng": 5.3664102, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Forel 11, Amersfoort", "lat": 52.2017125, "lng": 5.3664070, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 13, Amersfoort", "lat": 52.2017577, "lng": 5.3663935, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 14, Amersfoort", "lat": 52.2028892, "lng": 5.3666203, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 15, Amersfoort", "lat": 52.2018049, "lng": 5.3663735, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 16, Amersfoort", "lat": 52.2029447, "lng": 5.3665935, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 17, Amersfoort", "lat": 52.2018460, "lng": 5.3663568, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 18, Amersfoort", "lat": 52.2029898, "lng": 5.3665802, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 19, Amersfoort", "lat": 52.2018932, "lng": 5.3663367, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Forel 20, Amersfoort", "lat": 52.2030350, "lng": 5.3665534, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 21, Amersfoort", "lat": 52.2019404, "lng": 5.3663333, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Forel 22, Amersfoort", "lat": 52.2030904, "lng": 5.3665667, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 23, Amersfoort", "lat": 52.2019856, "lng": 5.3663266, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Forel 24, Amersfoort", "lat": 52.2031376, "lng": 5.3665534, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 25, Amersfoort", "lat": 52.2020267, "lng": 5.3663031, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Forel 26, Amersfoort", "lat": 52.2031808, "lng": 5.3665166, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 27, Amersfoort", "lat": 52.2021581, "lng": 5.3662931, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Forel 28, Amersfoort", "lat": 52.2032300, "lng": 5.3665065, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 29, Amersfoort", "lat": 52.2022033, "lng": 5.3662931, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 30, Amersfoort", "lat": 52.2032732, "lng": 5.3664932, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 31, Amersfoort", "lat": 52.2022423, "lng": 5.3662897, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 32, Amersfoort", "lat": 52.2033225, "lng": 5.3664830, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 33, Amersfoort", "lat": 52.2022957, "lng": 5.3662897, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 34, Amersfoort", "lat": 52.2034570, "lng": 5.3664553, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 35, Amersfoort", "lat": 52.2023409, "lng": 5.3662796, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Forel 36, Amersfoort", "lat": 52.2034997, "lng": 5.3664540, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 37, Amersfoort", "lat": 52.2023860, "lng": 5.3662829, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 38, Amersfoort", "lat": 52.2035517, "lng": 5.3664540, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 39, Amersfoort", "lat": 52.2024312, "lng": 5.3662863, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 40, Amersfoort", "lat": 52.2035979, "lng": 5.3664633, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 41, Amersfoort", "lat": 52.2024784, "lng": 5.3662829, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Forel 42, Amersfoort", "lat": 52.2036531, "lng": 5.3664807, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 43, Amersfoort", "lat": 52.2025236, "lng": 5.3662829, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Forel 44, Amersfoort", "lat": 52.2036934, "lng": 5.3664861, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 45, Amersfoort", "lat": 52.2025770, "lng": 5.3662795, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Forel 46, Amersfoort", "lat": 52.2037421, "lng": 5.3664739, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 48, Amersfoort", "lat": 52.2037865, "lng": 5.3664793, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 50, Amersfoort", "lat": 52.2038401, "lng": 5.3664753, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 52, Amersfoort", "lat": 52.2039390, "lng": 5.3663075, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 54, Amersfoort", "lat": 52.2039909, "lng": 5.3662942, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 56, Amersfoort", "lat": 52.2040370, "lng": 5.3662848, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 58, Amersfoort", "lat": 52.2040848, "lng": 5.3662700, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 60, Amersfoort", "lat": 52.2041400, "lng": 5.3662767, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 62, Amersfoort", "lat": 52.2041854, "lng": 5.3662578, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 64, Amersfoort", "lat": 52.2042315, "lng": 5.3662391, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Forel 66, Amersfoort", "lat": 52.2042736, "lng": 5.3662284, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 68, Amersfoort", "lat": 52.2043287, "lng": 5.3662055, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 70, Amersfoort", "lat": 52.2044571, "lng": 5.3661964, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 72, Amersfoort", "lat": 52.2045124, "lng": 5.3661836, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Forel 74, Amersfoort", "lat": 52.2045597, "lng": 5.3661621, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 76, Amersfoort", "lat": 52.2046071, "lng": 5.3661407, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 78, Amersfoort", "lat": 52.2046438, "lng": 5.3661578, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 80, Amersfoort", "lat": 52.2046935, "lng": 5.3661772, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 82, Amersfoort", "lat": 52.2047545, "lng": 5.3661749, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Forel 84, Amersfoort", "lat": 52.2047913, "lng": 5.3661835, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Forel 86, Amersfoort", "lat": 52.2048334, "lng": 5.3661835, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Forel 350, Amersfoort", "lat": 52.2063282, "lng": 5.3682781, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Forel 352, Amersfoort", "lat": 52.2063470, "lng": 5.3683435, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 354, Amersfoort", "lat": 52.2063631, "lng": 5.3684133, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 356, Amersfoort", "lat": 52.2063766, "lng": 5.3684787, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 358, Amersfoort", "lat": 52.2063953, "lng": 5.3685597, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 360, Amersfoort", "lat": 52.2064081, "lng": 5.3686390, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 362, Amersfoort", "lat": 52.2064194, "lng": 5.3687332, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 364, Amersfoort", "lat": 52.2064317, "lng": 5.3688020, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 366, Amersfoort", "lat": 52.2064479, "lng": 5.3688839, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 368, Amersfoort", "lat": 52.2064670, "lng": 5.3689572, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 370, Amersfoort", "lat": 52.2064831, "lng": 5.3690356, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 372, Amersfoort", "lat": 52.2064918, "lng": 5.3690802, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 374, Amersfoort", "lat": 52.2065481, "lng": 5.3692960, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Forel 376, Amersfoort", "lat": 52.2065588, "lng": 5.3693570, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 378, Amersfoort", "lat": 52.2065695, "lng": 5.3694311, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 380, Amersfoort", "lat": 52.2065802, "lng": 5.3695009, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 382, Amersfoort", "lat": 52.2065910, "lng": 5.3695881, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 384, Amersfoort", "lat": 52.2066017, "lng": 5.3696753, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 386, Amersfoort", "lat": 52.2066124, "lng": 5.3697493, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 388, Amersfoort", "lat": 52.2066231, "lng": 5.3698147, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 390, Amersfoort", "lat": 52.2066397, "lng": 5.3699155, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 392, Amersfoort", "lat": 52.2066524, "lng": 5.3699934, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 394, Amersfoort", "lat": 52.2066575, "lng": 5.3700721, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 396, Amersfoort", "lat": 52.2066661, "lng": 5.3701594, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Forel 398, Amersfoort", "lat": 52.2066774, "lng": 5.3702292, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Forel 400, Amersfoort", "lat": 52.2066886, "lng": 5.3703141, "expected_has_charger": None},  # 201m², 1vbo
    {"adres": "Forel 402, Amersfoort", "lat": 52.2067009, "lng": 5.3705318, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Forel 404, Amersfoort", "lat": 52.2067156, "lng": 5.3706147, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 406, Amersfoort", "lat": 52.2067237, "lng": 5.3706888, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 408, Amersfoort", "lat": 52.2067317, "lng": 5.3707760, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 410, Amersfoort", "lat": 52.2067371, "lng": 5.3708414, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 412, Amersfoort", "lat": 52.2067424, "lng": 5.3709285, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 414, Amersfoort", "lat": 52.2067452, "lng": 5.3710113, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 416, Amersfoort", "lat": 52.2067532, "lng": 5.3710855, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 418, Amersfoort", "lat": 52.2067666, "lng": 5.3711683, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 420, Amersfoort", "lat": 52.2067720, "lng": 5.3712511, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 422, Amersfoort", "lat": 52.2067827, "lng": 5.3713253, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Forel 424, Amersfoort", "lat": 52.2067854, "lng": 5.3714037, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Forel 426, Amersfoort", "lat": 52.2067935, "lng": 5.3714691, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Forel 428, Amersfoort", "lat": 52.2067935, "lng": 5.3715520, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gaardendreef 1, Amersfoort", "lat": 52.1981281, "lng": 5.3696116, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Gaardendreef 2, Amersfoort", "lat": 52.1980005, "lng": 5.3696703, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Gaardendreef 3, Amersfoort", "lat": 52.1979514, "lng": 5.3696863, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Gaardendreef 4, Amersfoort", "lat": 52.1978336, "lng": 5.3697289, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Gaardendreef 5, Amersfoort", "lat": 52.1977845, "lng": 5.3697448, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Gaardendreef 6, Amersfoort", "lat": 52.1976798, "lng": 5.3697928, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Gaardendreef 7, Amersfoort", "lat": 52.1976242, "lng": 5.3698195, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Gaardendreef 8, Amersfoort", "lat": 52.1975228, "lng": 5.3698834, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Gaardendreef 9, Amersfoort", "lat": 52.1974704, "lng": 5.3699101, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Gaardendreef 10, Amersfoort", "lat": 52.1973625, "lng": 5.3699793, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Gaardendreef 11, Amersfoort", "lat": 52.1973167, "lng": 5.3700060, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Gaardendreef 12, Amersfoort", "lat": 52.1972087, "lng": 5.3700913, "expected_has_charger": None},  # 204m², 1vbo
    {"adres": "Gaardendreef 13, Amersfoort", "lat": 52.1969961, "lng": 5.3702777, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Gaardendreef 14, Amersfoort", "lat": 52.1969044, "lng": 5.3703628, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Gaardendreef 15, Amersfoort", "lat": 52.1968554, "lng": 5.3704215, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Gaardendreef 16, Amersfoort", "lat": 52.1967670, "lng": 5.3705228, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Gaardendreef 17, Amersfoort", "lat": 52.1967147, "lng": 5.3705653, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Gaardendreef 18, Amersfoort", "lat": 52.1966330, "lng": 5.3706931, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Gaardendreef 19, Amersfoort", "lat": 52.1965839, "lng": 5.3707411, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Gaardendreef 20, Amersfoort", "lat": 52.1965086, "lng": 5.3708689, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Gaardendreef 21, Amersfoort", "lat": 52.1964629, "lng": 5.3709222, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Gaardendreef 22, Amersfoort", "lat": 52.1963712, "lng": 5.3710500, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Gaardendreef 23, Amersfoort", "lat": 52.1963221, "lng": 5.3710926, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Gaardendreef 24, Amersfoort", "lat": 52.1961880, "lng": 5.3711086, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Gaardendreef 25, Amersfoort", "lat": 52.1961324, "lng": 5.3710927, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Gaardendreef 26, Amersfoort", "lat": 52.1960180, "lng": 5.3710351, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Gaardendreef 27, Amersfoort", "lat": 52.1959742, "lng": 5.3709826, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gaardendreef 28, Amersfoort", "lat": 52.1957737, "lng": 5.3716094, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Gaardendreef 29, Amersfoort", "lat": 52.1958151, "lng": 5.3716693, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Gaardendreef 30, Amersfoort", "lat": 52.1958903, "lng": 5.3718530, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Gaardendreef 31, Amersfoort", "lat": 52.1958993, "lng": 5.3719370, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Gaardendreef 32, Amersfoort", "lat": 52.1958846, "lng": 5.3721643, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Gaardendreef 33, Amersfoort", "lat": 52.1958628, "lng": 5.3722440, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Gaardendreef 34, Amersfoort", "lat": 52.1958189, "lng": 5.3724061, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Gaardendreef 35, Amersfoort", "lat": 52.1957971, "lng": 5.3724884, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Gaardendreef 36, Amersfoort", "lat": 52.1957553, "lng": 5.3726481, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Gaardendreef 37, Amersfoort", "lat": 52.1957321, "lng": 5.3727382, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Gaardendreef 38, Amersfoort", "lat": 52.1956533, "lng": 5.3731295, "expected_has_charger": None},  # 202m², 1vbo
    {"adres": "Gaardendreef 39, Amersfoort", "lat": 52.1956409, "lng": 5.3732028, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Gaardendreef 40, Amersfoort", "lat": 52.1956170, "lng": 5.3733732, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Gaardendreef 41, Amersfoort", "lat": 52.1955963, "lng": 5.3734596, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Gaardendreef 42, Amersfoort", "lat": 52.1955732, "lng": 5.3736473, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Gaardendreef 43, Amersfoort", "lat": 52.1955571, "lng": 5.3737523, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Gaardendreef 44, Amersfoort", "lat": 52.1955341, "lng": 5.3739325, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Gaardendreef 45, Amersfoort", "lat": 52.1955311, "lng": 5.3739988, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Gaardendreef 46, Amersfoort", "lat": 52.1954834, "lng": 5.3743265, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Gaardendreef 47, Amersfoort", "lat": 52.1954718, "lng": 5.3744166, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Gaardendreef 48, Amersfoort", "lat": 52.1954534, "lng": 5.3746005, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Gaardendreef 49, Amersfoort", "lat": 52.1954396, "lng": 5.3747018, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Gaardendreef 50, Amersfoort", "lat": 52.1954235, "lng": 5.3748782, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Gaardendreef 51, Amersfoort", "lat": 52.1954143, "lng": 5.3749870, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Gaardendreef 52, Amersfoort", "lat": 52.1953422, "lng": 5.3751323, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Gaardendreef 53, Amersfoort", "lat": 52.1953924, "lng": 5.3752395, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Gaardendreef 54, Amersfoort", "lat": 52.1953728, "lng": 5.3756212, "expected_has_charger": None},  # 202m², 1vbo
    {"adres": "Gaardendreef 55, Amersfoort", "lat": 52.1953728, "lng": 5.3757413, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Gaardendreef 56, Amersfoort", "lat": 52.1953567, "lng": 5.3759154, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Gaardendreef 57, Amersfoort", "lat": 52.1953636, "lng": 5.3759965, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Gaardendreef 58, Amersfoort", "lat": 52.1953406, "lng": 5.3762029, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Gaardendreef 59, Amersfoort", "lat": 52.1953083, "lng": 5.3762817, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Gele Plomp 1, Amersfoort", "lat": 52.2058178, "lng": 5.3745708, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 2, Amersfoort", "lat": 52.2047702, "lng": 5.3737895, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Gele Plomp 3, Amersfoort", "lat": 52.2058162, "lng": 5.3744854, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 4, Amersfoort", "lat": 52.2047595, "lng": 5.3738840, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gele Plomp 5, Amersfoort", "lat": 52.2058178, "lng": 5.3744182, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 6, Amersfoort", "lat": 52.2047574, "lng": 5.3739715, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gele Plomp 7, Amersfoort", "lat": 52.2058241, "lng": 5.3743354, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 8, Amersfoort", "lat": 52.2047482, "lng": 5.3740563, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gele Plomp 9, Amersfoort", "lat": 52.2058241, "lng": 5.3742604, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 10, Amersfoort", "lat": 52.2047435, "lng": 5.3741314, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gele Plomp 11, Amersfoort", "lat": 52.2058273, "lng": 5.3741906, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 12, Amersfoort", "lat": 52.2047340, "lng": 5.3742142, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gele Plomp 13, Amersfoort", "lat": 52.2058273, "lng": 5.3741129, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 14, Amersfoort", "lat": 52.2047276, "lng": 5.3742995, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gele Plomp 15, Amersfoort", "lat": 52.2058321, "lng": 5.3740327, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Gele Plomp 16, Amersfoort", "lat": 52.2047197, "lng": 5.3743823, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Gele Plomp 17, Amersfoort", "lat": 52.2058336, "lng": 5.3739681, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Gele Plomp 18, Amersfoort", "lat": 52.2049660, "lng": 5.3748503, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 20, Amersfoort", "lat": 52.2050328, "lng": 5.3748452, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 22, Amersfoort", "lat": 52.2050996, "lng": 5.3748323, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Gele Plomp 24, Amersfoort", "lat": 52.2051646, "lng": 5.3748270, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 26, Amersfoort", "lat": 52.2052330, "lng": 5.3748219, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 28, Amersfoort", "lat": 52.2052966, "lng": 5.3748347, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 30, Amersfoort", "lat": 52.2054555, "lng": 5.3748555, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 32, Amersfoort", "lat": 52.2055223, "lng": 5.3748683, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 34, Amersfoort", "lat": 52.2055874, "lng": 5.3748736, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 36, Amersfoort", "lat": 52.2056574, "lng": 5.3749019, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 38, Amersfoort", "lat": 52.2057193, "lng": 5.3749329, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 40, Amersfoort", "lat": 52.2057813, "lng": 5.3749692, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Gele Plomp 42, Amersfoort", "lat": 52.2058830, "lng": 5.3750234, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Gele Plomp 44, Amersfoort", "lat": 52.2059434, "lng": 5.3750260, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Gele Plomp 46, Amersfoort", "lat": 52.2059863, "lng": 5.3750053, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Gele Plomp 48, Amersfoort", "lat": 52.2060276, "lng": 5.3749536, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Gele Plomp 50, Amersfoort", "lat": 52.2060562, "lng": 5.3748759, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Gele Plomp 52, Amersfoort", "lat": 52.2060658, "lng": 5.3747829, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Gele Plomp 54, Amersfoort", "lat": 52.2060577, "lng": 5.3745940, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gele Plomp 56, Amersfoort", "lat": 52.2060641, "lng": 5.3744906, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gele Plomp 58, Amersfoort", "lat": 52.2060657, "lng": 5.3744104, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gele Plomp 60, Amersfoort", "lat": 52.2060689, "lng": 5.3743146, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gele Plomp 62, Amersfoort", "lat": 52.2060752, "lng": 5.3742319, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gele Plomp 64, Amersfoort", "lat": 52.2060768, "lng": 5.3741284, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gele Plomp 66, Amersfoort", "lat": 52.2060704, "lng": 5.3740559, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Gele Plomp 68, Amersfoort", "lat": 52.2060721, "lng": 5.3739707, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Glaskruid 3, Amersfoort", "lat": 52.2015056, "lng": 5.3816968, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Glaskruid 4, Amersfoort", "lat": 52.2017277, "lng": 5.3812377, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Glaskruid 5, Amersfoort", "lat": 52.2014341, "lng": 5.3816905, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Glaskruid 6, Amersfoort", "lat": 52.2016756, "lng": 5.3812597, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Glaskruid 7, Amersfoort", "lat": 52.2013452, "lng": 5.3816968, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Glaskruid 8, Amersfoort", "lat": 52.2015751, "lng": 5.3812974, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Glaskruid 9, Amersfoort", "lat": 52.2012757, "lng": 5.3816810, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Glaskruid 10, Amersfoort", "lat": 52.2015133, "lng": 5.3813132, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Glaskruid 11, Amersfoort", "lat": 52.2011946, "lng": 5.3816684, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Glaskruid 12, Amersfoort", "lat": 52.2014071, "lng": 5.3813132, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Glaskruid 13, Amersfoort", "lat": 52.2011153, "lng": 5.3816465, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Glaskruid 14, Amersfoort", "lat": 52.2013433, "lng": 5.3813037, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Glaskruid 15, Amersfoort", "lat": 52.2010477, "lng": 5.3816276, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Glaskruid 16, Amersfoort", "lat": 52.2012428, "lng": 5.3812629, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Glaskruid 17, Amersfoort", "lat": 52.2009472, "lng": 5.3816654, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Glaskruid 18, Amersfoort", "lat": 52.2011946, "lng": 5.3812504, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Glaskruid 19, Amersfoort", "lat": 52.2008565, "lng": 5.3817283, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Glaskruid 20, Amersfoort", "lat": 52.2010844, "lng": 5.3811812, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Glaskruid 21, Amersfoort", "lat": 52.2007753, "lng": 5.3817975, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Glaskruid 22, Amersfoort", "lat": 52.2010322, "lng": 5.3811497, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Glaskruid 23, Amersfoort", "lat": 52.2006807, "lng": 5.3818635, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Glaskruid 24, Amersfoort", "lat": 52.2009163, "lng": 5.3810177, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Glaskruid 26, Amersfoort", "lat": 52.2008758, "lng": 5.3809485, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Glaskruid 28, Amersfoort", "lat": 52.2008062, "lng": 5.3808196, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Glaskruid 30, Amersfoort", "lat": 52.2007675, "lng": 5.3807442, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Glaskruid 34, Amersfoort", "lat": 52.2005821, "lng": 5.3810429, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Glaskruid 36, Amersfoort", "lat": 52.2005783, "lng": 5.3812661, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Glaskruid 38, Amersfoort", "lat": 52.2005415, "lng": 5.3814737, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Glaskruid 40, Amersfoort", "lat": 52.2005126, "lng": 5.3817125, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Glaskruid 42, Amersfoort", "lat": 52.2004778, "lng": 5.3819422, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Glaskruid 44, Amersfoort", "lat": 52.2004585, "lng": 5.3821559, "expected_has_charger": None},  # 201m², 1vbo
    {"adres": "Glaskruid 46, Amersfoort", "lat": 52.2004412, "lng": 5.3823886, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Glorie van Hollandgaarde 2, Amersfoort", "lat": 52.1949398, "lng": 5.3746050, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 4, Amersfoort", "lat": 52.1949329, "lng": 5.3746900, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 6, Amersfoort", "lat": 52.1949284, "lng": 5.3747676, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 8, Amersfoort", "lat": 52.1949193, "lng": 5.3748453, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 10, Amersfoort", "lat": 52.1949102, "lng": 5.3749230, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 12, Amersfoort", "lat": 52.1949034, "lng": 5.3750006, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 14, Amersfoort", "lat": 52.1948966, "lng": 5.3750820, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Glorie van Hollandgaarde 16, Amersfoort", "lat": 52.1948239, "lng": 5.3755183, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Glorie van Hollandgaarde 18, Amersfoort", "lat": 52.1948217, "lng": 5.3756070, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 20, Amersfoort", "lat": 52.1948149, "lng": 5.3756884, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 22, Amersfoort", "lat": 52.1948104, "lng": 5.3757586, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 24, Amersfoort", "lat": 52.1948058, "lng": 5.3758510, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Glorie van Hollandgaarde 26, Amersfoort", "lat": 52.1948036, "lng": 5.3759287, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Goudreinetgaarde 2, Amersfoort", "lat": 52.1977589, "lng": 5.3737597, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Goudreinetgaarde 4, Amersfoort", "lat": 52.1977360, "lng": 5.3738343, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 6, Amersfoort", "lat": 52.1977262, "lng": 5.3739035, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 8, Amersfoort", "lat": 52.1977065, "lng": 5.3739781, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 10, Amersfoort", "lat": 52.1976902, "lng": 5.3740420, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 12, Amersfoort", "lat": 52.1976706, "lng": 5.3741271, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 14, Amersfoort", "lat": 52.1976575, "lng": 5.3741965, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 16, Amersfoort", "lat": 52.1976379, "lng": 5.3742763, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Goudreinetgaarde 18, Amersfoort", "lat": 52.1974809, "lng": 5.3754371, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Goudreinetgaarde 20, Amersfoort", "lat": 52.1974744, "lng": 5.3755277, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 22, Amersfoort", "lat": 52.1974679, "lng": 5.3756021, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 24, Amersfoort", "lat": 52.1974646, "lng": 5.3756767, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 26, Amersfoort", "lat": 52.1974581, "lng": 5.3757566, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 28, Amersfoort", "lat": 52.1974515, "lng": 5.3758364, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 30, Amersfoort", "lat": 52.1974482, "lng": 5.3759163, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 32, Amersfoort", "lat": 52.1974482, "lng": 5.3759962, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Goudreinetgaarde 34, Amersfoort", "lat": 52.1974418, "lng": 5.3760708, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Groninger Kroongaarde 1, Amersfoort", "lat": 52.1949784, "lng": 5.3742796, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Groninger Kroongaarde 2, Amersfoort", "lat": 52.1943216, "lng": 5.3740431, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Groninger Kroongaarde 3, Amersfoort", "lat": 52.1949170, "lng": 5.3742721, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 4, Amersfoort", "lat": 52.1943216, "lng": 5.3741244, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 5, Amersfoort", "lat": 52.1948534, "lng": 5.3742574, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Groninger Kroongaarde 6, Amersfoort", "lat": 52.1943171, "lng": 5.3742021, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 7, Amersfoort", "lat": 52.1947988, "lng": 5.3742390, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Groninger Kroongaarde 8, Amersfoort", "lat": 52.1943103, "lng": 5.3742760, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 9, Amersfoort", "lat": 52.1947261, "lng": 5.3742279, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Groninger Kroongaarde 10, Amersfoort", "lat": 52.1943081, "lng": 5.3743647, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 11, Amersfoort", "lat": 52.1946716, "lng": 5.3742131, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Groninger Kroongaarde 12, Amersfoort", "lat": 52.1943035, "lng": 5.3744351, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 13, Amersfoort", "lat": 52.1946056, "lng": 5.3741909, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Groninger Kroongaarde 14, Amersfoort", "lat": 52.1942967, "lng": 5.3745126, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 15, Amersfoort", "lat": 52.1945557, "lng": 5.3741909, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "Groninger Kroongaarde 16, Amersfoort", "lat": 52.1942922, "lng": 5.3745903, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 17, Amersfoort", "lat": 52.1950512, "lng": 5.3759065, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Groninger Kroongaarde 18, Amersfoort", "lat": 52.1942876, "lng": 5.3746717, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 19, Amersfoort", "lat": 52.1950535, "lng": 5.3758250, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Groninger Kroongaarde 20, Amersfoort", "lat": 52.1942808, "lng": 5.3747456, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 21, Amersfoort", "lat": 52.1950557, "lng": 5.3757401, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Groninger Kroongaarde 22, Amersfoort", "lat": 52.1942785, "lng": 5.3748269, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 23, Amersfoort", "lat": 52.1950557, "lng": 5.3756624, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Groninger Kroongaarde 24, Amersfoort", "lat": 52.1942717, "lng": 5.3749084, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 25, Amersfoort", "lat": 52.1950626, "lng": 5.3755774, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Groninger Kroongaarde 26, Amersfoort", "lat": 52.1942672, "lng": 5.3749822, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Groninger Kroongaarde 28, Amersfoort", "lat": 52.1942627, "lng": 5.3750674, "expected_has_charger": None},  # 183m², 1vbo
    {"adres": "Groninger Kroongaarde 30, Amersfoort", "lat": 52.1942558, "lng": 5.3752448, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Groninger Kroongaarde 32, Amersfoort", "lat": 52.1942536, "lng": 5.3753335, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 34, Amersfoort", "lat": 52.1942536, "lng": 5.3754149, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 36, Amersfoort", "lat": 52.1942536, "lng": 5.3754889, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Groninger Kroongaarde 38, Amersfoort", "lat": 52.1942491, "lng": 5.3755702, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 40, Amersfoort", "lat": 52.1942468, "lng": 5.3756515, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 42, Amersfoort", "lat": 52.1942422, "lng": 5.3757255, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 44, Amersfoort", "lat": 52.1942423, "lng": 5.3758032, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 46, Amersfoort", "lat": 52.1942423, "lng": 5.3758845, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Groninger Kroongaarde 48, Amersfoort", "lat": 52.1942423, "lng": 5.3759695, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Grote Poelslak 1, Amersfoort", "lat": 52.2012070, "lng": 5.3695235, "expected_has_charger": None},  # 224m², 1vbo
    {"adres": "Grote Poelslak 2, Amersfoort", "lat": 52.2012165, "lng": 5.3696772, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Grote Poelslak 3, Amersfoort", "lat": 52.2012141, "lng": 5.3697846, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Grote Poelslak 4, Amersfoort", "lat": 52.2012170, "lng": 5.3699398, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Grote Poelslak 5, Amersfoort", "lat": 52.2012200, "lng": 5.3700577, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Grote Poelslak 6, Amersfoort", "lat": 52.2012192, "lng": 5.3701954, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Grote Poelslak 7, Amersfoort", "lat": 52.2012220, "lng": 5.3703070, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Grote Poelslak 8, Amersfoort", "lat": 52.2012207, "lng": 5.3704649, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Grote Poelslak 9, Amersfoort", "lat": 52.2012300, "lng": 5.3705861, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Grote Poelslak 10, Amersfoort", "lat": 52.2012379, "lng": 5.3707316, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Grote Poelslak 11, Amersfoort", "lat": 52.2012515, "lng": 5.3708255, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Grote Poelslak 12, Amersfoort", "lat": 52.2012586, "lng": 5.3709896, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Grote Poelslak 13, Amersfoort", "lat": 52.2012816, "lng": 5.3711189, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Grote Poelslak 14, Amersfoort", "lat": 52.2012951, "lng": 5.3712345, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Grote Poelslak 15, Amersfoort", "lat": 52.2013043, "lng": 5.3714564, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Grote Poelslak 16, Amersfoort", "lat": 52.2013560, "lng": 5.3716088, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Grote Poelslak 17, Amersfoort", "lat": 52.2013805, "lng": 5.3716923, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Grote Poelslak 18, Amersfoort", "lat": 52.2014148, "lng": 5.3718366, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Grote Poelslak 19, Amersfoort", "lat": 52.2014414, "lng": 5.3719576, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Grote Poelslak 20, Amersfoort", "lat": 52.2014761, "lng": 5.3720869, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Grote Poelslak 21, Amersfoort", "lat": 52.2015091, "lng": 5.3721830, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Grote Poelslak 22, Amersfoort", "lat": 52.2015495, "lng": 5.3722997, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Grote Poelslak 23, Amersfoort", "lat": 52.2015850, "lng": 5.3723898, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Grote Poelslak 24, Amersfoort", "lat": 52.2016537, "lng": 5.3725233, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Grote Poelslak 25, Amersfoort", "lat": 52.2016968, "lng": 5.3726161, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Grote Poelslak 26, Amersfoort", "lat": 52.2017420, "lng": 5.3727435, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Heelkruid 2, Amersfoort", "lat": 52.2021662, "lng": 5.3809735, "expected_has_charger": None},  # 84m², 1vbo
    {"adres": "Heelkruid 3, Amersfoort", "lat": 52.2016137, "lng": 5.3807473, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 4, Amersfoort", "lat": 52.2021334, "lng": 5.3809106, "expected_has_charger": None},  # 84m², 1vbo
    {"adres": "Heelkruid 5, Amersfoort", "lat": 52.2015654, "lng": 5.3807661, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 6, Amersfoort", "lat": 52.2020967, "lng": 5.3808635, "expected_has_charger": None},  # 84m², 1vbo
    {"adres": "Heelkruid 7, Amersfoort", "lat": 52.2015171, "lng": 5.3807818, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 8, Amersfoort", "lat": 52.2020620, "lng": 5.3808069, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Heelkruid 9, Amersfoort", "lat": 52.2014689, "lng": 5.3807881, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 10, Amersfoort", "lat": 52.2020252, "lng": 5.3807503, "expected_has_charger": None},  # 84m², 1vbo
    {"adres": "Heelkruid 11, Amersfoort", "lat": 52.2014244, "lng": 5.3807913, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 12, Amersfoort", "lat": 52.2019943, "lng": 5.3807000, "expected_has_charger": None},  # 84m², 1vbo
    {"adres": "Heelkruid 13, Amersfoort", "lat": 52.2013742, "lng": 5.3807881, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 14, Amersfoort", "lat": 52.2019556, "lng": 5.3806371, "expected_has_charger": None},  # 84m², 1vbo
    {"adres": "Heelkruid 15, Amersfoort", "lat": 52.2013220, "lng": 5.3807755, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 16, Amersfoort", "lat": 52.2018146, "lng": 5.3804737, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Heelkruid 17A, Amersfoort", "lat": 52.2012786, "lng": 5.3807684, "expected_has_charger": None},  # 89m², 2vbo
    {"adres": "Heelkruid 18, Amersfoort", "lat": 52.2018378, "lng": 5.3804013, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 19, Amersfoort", "lat": 52.2012351, "lng": 5.3807222, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 20, Amersfoort", "lat": 52.2018610, "lng": 5.3803290, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Heelkruid 21, Amersfoort", "lat": 52.2011868, "lng": 5.3806875, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 22, Amersfoort", "lat": 52.2018764, "lng": 5.3802535, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Heelkruid 23, Amersfoort", "lat": 52.2011366, "lng": 5.3806215, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Heelkruid 24, Amersfoort", "lat": 52.2018900, "lng": 5.3801780, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 25, Amersfoort", "lat": 52.2011018, "lng": 5.3805649, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 26, Amersfoort", "lat": 52.2018977, "lng": 5.3800963, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 27, Amersfoort", "lat": 52.2010709, "lng": 5.3805052, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 28, Amersfoort", "lat": 52.2018996, "lng": 5.3800177, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 29, Amersfoort", "lat": 52.2010399, "lng": 5.3804391, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Heelkruid 30, Amersfoort", "lat": 52.2018919, "lng": 5.3799455, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 31, Amersfoort", "lat": 52.2010167, "lng": 5.3803732, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Heelkruid 32, Amersfoort", "lat": 52.2018841, "lng": 5.3798700, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 33, Amersfoort", "lat": 52.2010034, "lng": 5.3802984, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 34, Amersfoort", "lat": 52.2018706, "lng": 5.3797945, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 35, Amersfoort", "lat": 52.2009865, "lng": 5.3802202, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 36, Amersfoort", "lat": 52.2018436, "lng": 5.3796876, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 37, Amersfoort", "lat": 52.2009793, "lng": 5.3801419, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 38, Amersfoort", "lat": 52.2018146, "lng": 5.3796216, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 39, Amersfoort", "lat": 52.2009746, "lng": 5.3800637, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 40, Amersfoort", "lat": 52.2017856, "lng": 5.3795618, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 41, Amersfoort", "lat": 52.2009746, "lng": 5.3799893, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 42, Amersfoort", "lat": 52.2017527, "lng": 5.3795021, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 43, Amersfoort", "lat": 52.2009817, "lng": 5.3799150, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Heelkruid 44, Amersfoort", "lat": 52.2017142, "lng": 5.3794549, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 45, Amersfoort", "lat": 52.2009865, "lng": 5.3798328, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 46, Amersfoort", "lat": 52.2016755, "lng": 5.3794047, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 47, Amersfoort", "lat": 52.2010034, "lng": 5.3797585, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Heelkruid 48, Amersfoort", "lat": 52.2016330, "lng": 5.3793733, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 49, Amersfoort", "lat": 52.2009714, "lng": 5.3796299, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Heelkruid 50, Amersfoort", "lat": 52.2015846, "lng": 5.3793386, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 51, Amersfoort", "lat": 52.2010442, "lng": 5.3796137, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 52, Amersfoort", "lat": 52.2015422, "lng": 5.3793134, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 53, Amersfoort", "lat": 52.2010707, "lng": 5.3795471, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 54, Amersfoort", "lat": 52.2014958, "lng": 5.3793009, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Heelkruid 55, Amersfoort", "lat": 52.2011092, "lng": 5.3794924, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Heelkruid 56, Amersfoort", "lat": 52.2014475, "lng": 5.3792757, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 57, Amersfoort", "lat": 52.2009420, "lng": 5.3792673, "expected_has_charger": None},  # 255m², 1vbo
    {"adres": "Heelkruid 58, Amersfoort", "lat": 52.2014011, "lng": 5.3792852, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 59, Amersfoort", "lat": 52.2006447, "lng": 5.3786946, "expected_has_charger": None},  # 350m², 1vbo
    {"adres": "Heelkruid 60, Amersfoort", "lat": 52.2013548, "lng": 5.3792946, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 62, Amersfoort", "lat": 52.2013064, "lng": 5.3793104, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Heelkruid 64, Amersfoort", "lat": 52.2012562, "lng": 5.3793261, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Heelkruid 66, Amersfoort", "lat": 52.2011769, "lng": 5.3790461, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Heelkruid 68, Amersfoort", "lat": 52.2011496, "lng": 5.3789728, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Heelkruid 70, Amersfoort", "lat": 52.2010835, "lng": 5.3788245, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Heelkruid 72, Amersfoort", "lat": 52.2010507, "lng": 5.3787532, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Heelkruid 74, Amersfoort", "lat": 52.2009856, "lng": 5.3786037, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Heelkruid 76, Amersfoort", "lat": 52.2009462, "lng": 5.3785225, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Heelkruid 78, Amersfoort", "lat": 52.2008796, "lng": 5.3783903, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Heelkruid 80, Amersfoort", "lat": 52.2008416, "lng": 5.3783084, "expected_has_charger": None},  # 184m², 1vbo
    {"adres": "Helmkruid 1, Amersfoort", "lat": 52.2017004, "lng": 5.3783607, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Helmkruid 2, Amersfoort", "lat": 52.2014469, "lng": 5.3783080, "expected_has_charger": None},  # 91m², 1vbo
    {"adres": "Helmkruid 3, Amersfoort", "lat": 52.2016983, "lng": 5.3784384, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Helmkruid 4, Amersfoort", "lat": 52.2014426, "lng": 5.3783820, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Helmkruid 5, Amersfoort", "lat": 52.2016895, "lng": 5.3785159, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Helmkruid 6, Amersfoort", "lat": 52.2014382, "lng": 5.3784595, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Helmkruid 7, Amersfoort", "lat": 52.2016831, "lng": 5.3785899, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Helmkruid 8, Amersfoort", "lat": 52.2014295, "lng": 5.3785407, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Helmkruid 9, Amersfoort", "lat": 52.2016766, "lng": 5.3786711, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Helmkruid 10, Amersfoort", "lat": 52.2014231, "lng": 5.3786217, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Helmkruid 11, Amersfoort", "lat": 52.2016571, "lng": 5.3787487, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Helmkruid 12, Amersfoort", "lat": 52.2014295, "lng": 5.3786959, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Helmkruid 13, Amersfoort", "lat": 52.2016506, "lng": 5.3788333, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Helmkruid 14, Amersfoort", "lat": 52.2014231, "lng": 5.3787804, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Het Blauwe Laken 1, Amersfoort", "lat": 52.1999818, "lng": 5.3806173, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Het Blauwe Laken 3, Amersfoort", "lat": 52.1999896, "lng": 5.3805537, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Blauwe Laken 5, Amersfoort", "lat": 52.1999959, "lng": 5.3804775, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Blauwe Laken 7, Amersfoort", "lat": 52.2000006, "lng": 5.3804011, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Blauwe Laken 9, Amersfoort", "lat": 52.2000084, "lng": 5.3803274, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Blauwe Laken 11, Amersfoort", "lat": 52.2000131, "lng": 5.3802562, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Blauwe Laken 13, Amersfoort", "lat": 52.2000177, "lng": 5.3801823, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Blauwe Laken 15, Amersfoort", "lat": 52.2000209, "lng": 5.3801061, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Blauwe Laken 17, Amersfoort", "lat": 52.2000287, "lng": 5.3800246, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Het Groene Schaap 1, Amersfoort", "lat": 52.1952509, "lng": 5.3798319, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Het Groene Schaap 2, Amersfoort", "lat": 52.1951563, "lng": 5.3794529, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Het Groene Schaap 3, Amersfoort", "lat": 52.1952094, "lng": 5.3798582, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Het Groene Schaap 4, Amersfoort", "lat": 52.1951102, "lng": 5.3794829, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "Het Groene Schaap 5, Amersfoort", "lat": 52.1951679, "lng": 5.3798920, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Groene Schaap 6, Amersfoort", "lat": 52.1950687, "lng": 5.3795054, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 7, Amersfoort", "lat": 52.1951218, "lng": 5.3799145, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Het Groene Schaap 8, Amersfoort", "lat": 52.1950203, "lng": 5.3795505, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Groene Schaap 9, Amersfoort", "lat": 52.1950756, "lng": 5.3799445, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Het Groene Schaap 10, Amersfoort", "lat": 52.1949787, "lng": 5.3795730, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 11, Amersfoort", "lat": 52.1950319, "lng": 5.3799783, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Groene Schaap 12, Amersfoort", "lat": 52.1949304, "lng": 5.3796068, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 13, Amersfoort", "lat": 52.1949904, "lng": 5.3800121, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Het Groene Schaap 14, Amersfoort", "lat": 52.1948911, "lng": 5.3796406, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 15, Amersfoort", "lat": 52.1949419, "lng": 5.3800383, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Het Groene Schaap 16, Amersfoort", "lat": 52.1948473, "lng": 5.3796706, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 17, Amersfoort", "lat": 52.1948981, "lng": 5.3800721, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Het Groene Schaap 18, Amersfoort", "lat": 52.1948035, "lng": 5.3797044, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 19, Amersfoort", "lat": 52.1948565, "lng": 5.3801097, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Het Groene Schaap 20, Amersfoort", "lat": 52.1947550, "lng": 5.3797306, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 21, Amersfoort", "lat": 52.1948035, "lng": 5.3801435, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Groene Schaap 22, Amersfoort", "lat": 52.1947020, "lng": 5.3797644, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Het Haagse Hofje 1, Amersfoort", "lat": 52.1950988, "lng": 5.3805187, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Het Haagse Hofje 2, Amersfoort", "lat": 52.1951425, "lng": 5.3804924, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Het Haagse Hofje 3, Amersfoort", "lat": 52.1951887, "lng": 5.3804624, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Het Haagse Hofje 4, Amersfoort", "lat": 52.1952279, "lng": 5.3803835, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Het Haagse Hofje 5, Amersfoort", "lat": 52.1952763, "lng": 5.3803535, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Haagse Hofje 6, Amersfoort", "lat": 52.1953271, "lng": 5.3803423, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Haagse Hofje 7, Amersfoort", "lat": 52.1953755, "lng": 5.3803648, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Het Haagse Hofje 8, Amersfoort", "lat": 52.1954216, "lng": 5.3804022, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Het Haagse Hofje 9, Amersfoort", "lat": 52.1954539, "lng": 5.3804661, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Het Haagse Hofje 10, Amersfoort", "lat": 52.1954654, "lng": 5.3805599, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Haagse Hofje 11, Amersfoort", "lat": 52.1955000, "lng": 5.3806237, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Haagse Hofje 12, Amersfoort", "lat": 52.1955323, "lng": 5.3806838, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Het Haagse Hofje 13, Amersfoort", "lat": 52.1955669, "lng": 5.3807363, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Het Haagse Hofje 14, Amersfoort", "lat": 52.1956038, "lng": 5.3808038, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Het Haagse Hofje 15, Amersfoort", "lat": 52.1956384, "lng": 5.3808714, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Haagse Hofje 16, Amersfoort", "lat": 52.1956753, "lng": 5.3809352, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Haagse Hofje 17, Amersfoort", "lat": 52.1957030, "lng": 5.3809989, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Het Halve Maantje 1, Amersfoort", "lat": 52.1994460, "lng": 5.3805867, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Het Halve Maantje 2, Amersfoort", "lat": 52.1993762, "lng": 5.3808779, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Het Halve Maantje 3, Amersfoort", "lat": 52.1995391, "lng": 5.3806013, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Het Halve Maantje 4, Amersfoort", "lat": 52.1995140, "lng": 5.3809477, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 5, Amersfoort", "lat": 52.1995873, "lng": 5.3806042, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 6, Amersfoort", "lat": 52.1995624, "lng": 5.3809652, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 7, Amersfoort", "lat": 52.1996339, "lng": 5.3806128, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Het Halve Maantje 8, Amersfoort", "lat": 52.1996088, "lng": 5.3809652, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 9, Amersfoort", "lat": 52.1996769, "lng": 5.3806216, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 10, Amersfoort", "lat": 52.1996536, "lng": 5.3809710, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 11, Amersfoort", "lat": 52.1997251, "lng": 5.3806333, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Het Halve Maantje 12, Amersfoort", "lat": 52.1997001, "lng": 5.3809826, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 13, Amersfoort", "lat": 52.1997645, "lng": 5.3806478, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 14, Amersfoort", "lat": 52.1997430, "lng": 5.3810001, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 15, Amersfoort", "lat": 52.1998092, "lng": 5.3806595, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Het Halve Maantje 16, Amersfoort", "lat": 52.1997931, "lng": 5.3810117, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 17, Amersfoort", "lat": 52.1999541, "lng": 5.3806886, "expected_has_charger": None},  # 80m², 1vbo
    {"adres": "Het Halve Maantje 18, Amersfoort", "lat": 52.1998343, "lng": 5.3810175, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 20, Amersfoort", "lat": 52.1998808, "lng": 5.3810263, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Het Halve Maantje 22, Amersfoort", "lat": 52.1999238, "lng": 5.3810321, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Het Halve Maantje 24, Amersfoort", "lat": 52.1999648, "lng": 5.3810408, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Het Halve Maantje 26, Amersfoort", "lat": 52.2001331, "lng": 5.3810408, "expected_has_charger": None},  # 80m², 1vbo
    {"adres": "Het Rode Hert 2, Amersfoort", "lat": 52.1956912, "lng": 5.3768820, "expected_has_charger": None},  # 206m², 1vbo
    {"adres": "Het Rode Hert 4, Amersfoort", "lat": 52.1959472, "lng": 5.3768971, "expected_has_charger": None},  # 215m², 1vbo
    {"adres": "Het Rode Hert 6, Amersfoort", "lat": 52.1960118, "lng": 5.3769008, "expected_has_charger": None},  # 184m², 1vbo
    {"adres": "Het Rode Hert 8, Amersfoort", "lat": 52.1960787, "lng": 5.3769008, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Het Rode Hert 10, Amersfoort", "lat": 52.1961432, "lng": 5.3768932, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Het Rode Hert 12, Amersfoort", "lat": 52.1962078, "lng": 5.3768895, "expected_has_charger": None},  # 201m², 1vbo
    {"adres": "Het Rode Hert 14, Amersfoort", "lat": 52.1962747, "lng": 5.3768819, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Het Rode Hert 16, Amersfoort", "lat": 52.1963415, "lng": 5.3768932, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Het Rode Hert 18, Amersfoort", "lat": 52.1964015, "lng": 5.3768857, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Het Rode Hert 20, Amersfoort", "lat": 52.1964707, "lng": 5.3768895, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Het Rode Hert 22, Amersfoort", "lat": 52.1965398, "lng": 5.3768819, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Het Rode Hert 24, Amersfoort", "lat": 52.1965975, "lng": 5.3768856, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Het Rode Hert 26, Amersfoort", "lat": 52.1966621, "lng": 5.3768856, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Het Rode Hert 28, Amersfoort", "lat": 52.1967289, "lng": 5.3768856, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Het Rode Hert 30, Amersfoort", "lat": 52.1968120, "lng": 5.3768856, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Het Rode Hert 32, Amersfoort", "lat": 52.1968788, "lng": 5.3768894, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Het Rode Hert 34, Amersfoort", "lat": 52.1969445, "lng": 5.3768856, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Het Rode Hert 36, Amersfoort", "lat": 52.1970046, "lng": 5.3768855, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Het Rode Hert 38, Amersfoort", "lat": 52.1970760, "lng": 5.3768855, "expected_has_charger": None},  # 201m², 1vbo
    {"adres": "Het Rode Hert 40, Amersfoort", "lat": 52.1971429, "lng": 5.3768893, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Het Rode Hert 42, Amersfoort", "lat": 52.1971983, "lng": 5.3768817, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Het Rode Hert 44, Amersfoort", "lat": 52.1972721, "lng": 5.3768780, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Het Rode Hert 46, Amersfoort", "lat": 52.1973332, "lng": 5.3768893, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Het Rode Hert 48, Amersfoort", "lat": 52.1974093, "lng": 5.3768967, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Het Rode Hert 50, Amersfoort", "lat": 52.1974762, "lng": 5.3768929, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Het Rode Hert 52, Amersfoort", "lat": 52.1975338, "lng": 5.3768854, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Het Rode Hert 54, Amersfoort", "lat": 52.1975937, "lng": 5.3769230, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Het Rode Hert 56, Amersfoort", "lat": 52.1976422, "lng": 5.3769942, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Het Rode Hert 58, Amersfoort", "lat": 52.1976837, "lng": 5.3770768, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Het Rode Hert 60, Amersfoort", "lat": 52.1977276, "lng": 5.3771481, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Het Rode Hert 62, Amersfoort", "lat": 52.1977690, "lng": 5.3772269, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Het Rode Hert 64, Amersfoort", "lat": 52.1978083, "lng": 5.3773057, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Het Rode Hert 66, Amersfoort", "lat": 52.1978544, "lng": 5.3773882, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Het Rode Hert 68, Amersfoort", "lat": 52.1978960, "lng": 5.3774746, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Het Rode Hert 70, Amersfoort", "lat": 52.1979421, "lng": 5.3775421, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Het Rode Hert 72, Amersfoort", "lat": 52.1979767, "lng": 5.3776247, "expected_has_charger": None},  # 204m², 1vbo
    {"adres": "Het Rode Hert 74, Amersfoort", "lat": 52.1981312, "lng": 5.3778047, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Het Zwarte Paard 1, Amersfoort", "lat": 52.1991880, "lng": 5.3837655, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Het Zwarte Paard 2, Amersfoort", "lat": 52.1995858, "lng": 5.3838482, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Het Zwarte Paard 3, Amersfoort", "lat": 52.1991900, "lng": 5.3836857, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 4, Amersfoort", "lat": 52.1995956, "lng": 5.3837749, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Het Zwarte Paard 5, Amersfoort", "lat": 52.1991900, "lng": 5.3836155, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 6, Amersfoort", "lat": 52.1996054, "lng": 5.3836952, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Het Zwarte Paard 7, Amersfoort", "lat": 52.1992018, "lng": 5.3835263, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 8, Amersfoort", "lat": 52.1996132, "lng": 5.3836219, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Het Zwarte Paard 9, Amersfoort", "lat": 52.1992038, "lng": 5.3834434, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 10, Amersfoort", "lat": 52.1996230, "lng": 5.3835390, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Het Zwarte Paard 11, Amersfoort", "lat": 52.1992076, "lng": 5.3833669, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 12, Amersfoort", "lat": 52.1996269, "lng": 5.3834593, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Het Zwarte Paard 13, Amersfoort", "lat": 52.1992136, "lng": 5.3832902, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 14, Amersfoort", "lat": 52.1996367, "lng": 5.3833828, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Het Zwarte Paard 15, Amersfoort", "lat": 52.1992233, "lng": 5.3832169, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Het Zwarte Paard 16, Amersfoort", "lat": 52.1996426, "lng": 5.3832998, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Het Zwarte Paard 17, Amersfoort", "lat": 52.1992292, "lng": 5.3831340, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 18, Amersfoort", "lat": 52.1996524, "lng": 5.3832296, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Het Zwarte Paard 19, Amersfoort", "lat": 52.1992390, "lng": 5.3830607, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Het Zwarte Paard 20, Amersfoort", "lat": 52.1996426, "lng": 5.3831563, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Hoge Boog 2, Amersfoort", "lat": 52.1967019, "lng": 5.3726206, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Hoge Boog 4, Amersfoort", "lat": 52.1969866, "lng": 5.3729027, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Hoge Boog 6, Amersfoort", "lat": 52.1972909, "lng": 5.3731849, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Hoge Boog 8, Amersfoort", "lat": 52.1975134, "lng": 5.3734030, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Hoge Boog 10, Amersfoort", "lat": 52.1977687, "lng": 5.3736693, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Hooglandsepoort 1, Amersfoort", "lat": 52.1947558, "lng": 5.3713474, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Hooglandsepoort 2, Amersfoort", "lat": 52.1948132, "lng": 5.3713352, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Hooglandsepoort 3, Amersfoort", "lat": 52.1949190, "lng": 5.3713252, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Hooglandsepoort 4, Amersfoort", "lat": 52.1949762, "lng": 5.3713106, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Hooglandsepoort 5, Amersfoort", "lat": 52.1950853, "lng": 5.3713105, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Hooglandsepoort 6, Amersfoort", "lat": 52.1951489, "lng": 5.3713061, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Hooglandsepoort 7, Amersfoort", "lat": 52.1952620, "lng": 5.3712992, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Hooglandsepoort 8, Amersfoort", "lat": 52.1953378, "lng": 5.3713156, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Hooglandsepoort 9, Amersfoort", "lat": 52.1954665, "lng": 5.3713768, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Hooglandsepoort 10, Amersfoort", "lat": 52.1955256, "lng": 5.3714211, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Hooglandsepoort 11, Amersfoort", "lat": 52.1956165, "lng": 5.3714840, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Hooglandsepoort 12, Amersfoort", "lat": 52.1956733, "lng": 5.3715246, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Huisjesslak 1, Amersfoort", "lat": 52.2021278, "lng": 5.3719163, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 3, Amersfoort", "lat": 52.2021667, "lng": 5.3718817, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 5, Amersfoort", "lat": 52.2022003, "lng": 5.3718414, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 7, Amersfoort", "lat": 52.2022409, "lng": 5.3717868, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 9, Amersfoort", "lat": 52.2022833, "lng": 5.3717638, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 11, Amersfoort", "lat": 52.2023239, "lng": 5.3717263, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 13, Amersfoort", "lat": 52.2023593, "lng": 5.3716688, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 15, Amersfoort", "lat": 52.2024017, "lng": 5.3716228, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 17, Amersfoort", "lat": 52.2024335, "lng": 5.3715911, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 19, Amersfoort", "lat": 52.2024706, "lng": 5.3715393, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Huisjesslak 21, Amersfoort", "lat": 52.2025094, "lng": 5.3714962, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Huisjesslak 23, Amersfoort", "lat": 52.2025483, "lng": 5.3714530, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Huisjesslak 25, Amersfoort", "lat": 52.2026914, "lng": 5.3713639, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Ingrid Mariegaarde 1, Amersfoort", "lat": 52.1974693, "lng": 5.3734748, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Ingrid Mariegaarde 2, Amersfoort", "lat": 52.1972842, "lng": 5.3732764, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Ingrid Mariegaarde 3, Amersfoort", "lat": 52.1974545, "lng": 5.3735502, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Ingrid Mariegaarde 4, Amersfoort", "lat": 52.1972610, "lng": 5.3733482, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 5, Amersfoort", "lat": 52.1974356, "lng": 5.3736220, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Ingrid Mariegaarde 6, Amersfoort", "lat": 52.1972464, "lng": 5.3734167, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 7, Amersfoort", "lat": 52.1974209, "lng": 5.3736973, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Ingrid Mariegaarde 8, Amersfoort", "lat": 52.1972253, "lng": 5.3734887, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 9, Amersfoort", "lat": 52.1974041, "lng": 5.3737692, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Ingrid Mariegaarde 10, Amersfoort", "lat": 52.1972064, "lng": 5.3735639, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 11, Amersfoort", "lat": 52.1973830, "lng": 5.3738445, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Ingrid Mariegaarde 12, Amersfoort", "lat": 52.1971917, "lng": 5.3736358, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 13, Amersfoort", "lat": 52.1973684, "lng": 5.3739232, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Ingrid Mariegaarde 14, Amersfoort", "lat": 52.1971728, "lng": 5.3737110, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 15, Amersfoort", "lat": 52.1973494, "lng": 5.3739950, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Ingrid Mariegaarde 16, Amersfoort", "lat": 52.1971538, "lng": 5.3737863, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 17, Amersfoort", "lat": 52.1973284, "lng": 5.3740703, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Ingrid Mariegaarde 18, Amersfoort", "lat": 52.1971307, "lng": 5.3738582, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 19, Amersfoort", "lat": 52.1973116, "lng": 5.3741421, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Ingrid Mariegaarde 20, Amersfoort", "lat": 52.1971160, "lng": 5.3739301, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 22, Amersfoort", "lat": 52.1970992, "lng": 5.3740053, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Ingrid Mariegaarde 24, Amersfoort", "lat": 52.1970782, "lng": 5.3740773, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Jaap Edenstraat 1, Amersfoort", "lat": 52.1956613, "lng": 5.3847284, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 3, Amersfoort", "lat": 52.1956613, "lng": 5.3846475, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 5, Amersfoort", "lat": 52.1956613, "lng": 5.3845684, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 7, Amersfoort", "lat": 52.1956613, "lng": 5.3844895, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 9, Amersfoort", "lat": 52.1956613, "lng": 5.3844105, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 11, Amersfoort", "lat": 52.1956613, "lng": 5.3843316, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 13, Amersfoort", "lat": 52.1956613, "lng": 5.3842526, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 15, Amersfoort", "lat": 52.1956613, "lng": 5.3841735, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 17, Amersfoort", "lat": 52.1956613, "lng": 5.3840946, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 19, Amersfoort", "lat": 52.1956613, "lng": 5.3840157, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 21, Amersfoort", "lat": 52.1956613, "lng": 5.3839367, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 23, Amersfoort", "lat": 52.1956613, "lng": 5.3838577, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jaap Edenstraat 25, Amersfoort", "lat": 52.1956613, "lng": 5.3837769, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "James Grievegaarde 1, Amersfoort", "lat": 52.1971561, "lng": 5.3753604, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "James Grievegaarde 2, Amersfoort", "lat": 52.1969311, "lng": 5.3752920, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "James Grievegaarde 3, Amersfoort", "lat": 52.1971540, "lng": 5.3754358, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 4, Amersfoort", "lat": 52.1969269, "lng": 5.3753674, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "James Grievegaarde 5, Amersfoort", "lat": 52.1971457, "lng": 5.3755178, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 6, Amersfoort", "lat": 52.1969227, "lng": 5.3754529, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "James Grievegaarde 7, Amersfoort", "lat": 52.1971414, "lng": 5.3756034, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 8, Amersfoort", "lat": 52.1969228, "lng": 5.3755316, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "James Grievegaarde 9, Amersfoort", "lat": 52.1971352, "lng": 5.3756718, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 10, Amersfoort", "lat": 52.1969143, "lng": 5.3756103, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "James Grievegaarde 11, Amersfoort", "lat": 52.1971309, "lng": 5.3757609, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 12, Amersfoort", "lat": 52.1969123, "lng": 5.3756890, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "James Grievegaarde 13, Amersfoort", "lat": 52.1971247, "lng": 5.3758361, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 14, Amersfoort", "lat": 52.1969059, "lng": 5.3757677, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "James Grievegaarde 15, Amersfoort", "lat": 52.1971204, "lng": 5.3759114, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 16, Amersfoort", "lat": 52.1968996, "lng": 5.3758430, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "James Grievegaarde 17, Amersfoort", "lat": 52.1971142, "lng": 5.3759936, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "James Grievegaarde 18, Amersfoort", "lat": 52.1968933, "lng": 5.3759252, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "James Grievegaarde 19, Amersfoort", "lat": 52.1971078, "lng": 5.3760688, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "James Grievegaarde 20, Amersfoort", "lat": 52.1968891, "lng": 5.3760039, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "James Grievegaarde 21, Amersfoort", "lat": 52.1971078, "lng": 5.3761612, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "James Grievegaarde 22, Amersfoort", "lat": 52.1968849, "lng": 5.3760826, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "James Grievegaarde 23, Amersfoort", "lat": 52.1974190, "lng": 5.3761509, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "James Grievegaarde 24, Amersfoort", "lat": 52.1968765, "lng": 5.3761579, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Johan Cruijffstraat 1, Amersfoort", "lat": 52.1959856, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 3, Amersfoort", "lat": 52.1959371, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 5, Amersfoort", "lat": 52.1958885, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 7, Amersfoort", "lat": 52.1958400, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 9, Amersfoort", "lat": 52.1957915, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 11, Amersfoort", "lat": 52.1957429, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 13, Amersfoort", "lat": 52.1956944, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 15, Amersfoort", "lat": 52.1956459, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 16, Amersfoort", "lat": 52.1957429, "lng": 5.3849925, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 17, Amersfoort", "lat": 52.1955962, "lng": 5.3855690, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 18, Amersfoort", "lat": 52.1956944, "lng": 5.3849925, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 20, Amersfoort", "lat": 52.1956459, "lng": 5.3849925, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Johan Cruijffstraat 22, Amersfoort", "lat": 52.1955962, "lng": 5.3849925, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Jonathangaarde 2, Amersfoort", "lat": 52.1952374, "lng": 5.3742018, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Jonathangaarde 4, Amersfoort", "lat": 52.1952283, "lng": 5.3742906, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Jonathangaarde 6, Amersfoort", "lat": 52.1952237, "lng": 5.3743645, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Jonathangaarde 8, Amersfoort", "lat": 52.1952169, "lng": 5.3744421, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Jonathangaarde 10, Amersfoort", "lat": 52.1952079, "lng": 5.3745198, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Jonathangaarde 12, Amersfoort", "lat": 52.1951988, "lng": 5.3746011, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Jonathangaarde 14, Amersfoort", "lat": 52.1951920, "lng": 5.3746751, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Jonathangaarde 16, Amersfoort", "lat": 52.1951852, "lng": 5.3747492, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Jonathangaarde 18, Amersfoort", "lat": 52.1951783, "lng": 5.3748341, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Jonathangaarde 20, Amersfoort", "lat": 52.1951738, "lng": 5.3749081, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Jonathangaarde 22, Amersfoort", "lat": 52.1951648, "lng": 5.3749895, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Jonathangaarde 24, Amersfoort", "lat": 52.1951580, "lng": 5.3750633, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Jonathangaarde 26, Amersfoort", "lat": 52.1951511, "lng": 5.3751484, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Juttepeergaarde 1, Amersfoort", "lat": 52.1979256, "lng": 5.3733789, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Juttepeergaarde 3, Amersfoort", "lat": 52.1979697, "lng": 5.3733240, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Juttepeergaarde 5, Amersfoort", "lat": 52.1980075, "lng": 5.3732660, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Juttepeergaarde 7, Amersfoort", "lat": 52.1980475, "lng": 5.3732248, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Juttepeergaarde 9, Amersfoort", "lat": 52.1980937, "lng": 5.3731804, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Juttepeergaarde 11, Amersfoort", "lat": 52.1981421, "lng": 5.3731461, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Juttepeergaarde 13, Amersfoort", "lat": 52.1981821, "lng": 5.3731016, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Juttepeergaarde 15, Amersfoort", "lat": 52.1982283, "lng": 5.3730639, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Juttepeergaarde 17, Amersfoort", "lat": 52.1982725, "lng": 5.3730297, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Juttepeergaarde 19, Amersfoort", "lat": 52.1983208, "lng": 5.3730023, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Juttepeergaarde 21, Amersfoort", "lat": 52.1983734, "lng": 5.3729852, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Kaasjeskruid 1, Amersfoort", "lat": 52.2022434, "lng": 5.3787387, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Kaasjeskruid 2, Amersfoort", "lat": 52.2020598, "lng": 5.3784711, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Kaasjeskruid 3, Amersfoort", "lat": 52.2022944, "lng": 5.3787439, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 4, Amersfoort", "lat": 52.2020486, "lng": 5.3785802, "expected_has_charger": None},  # 210m², 1vbo
    {"adres": "Kaasjeskruid 5, Amersfoort", "lat": 52.2023392, "lng": 5.3787595, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 6, Amersfoort", "lat": 52.2020247, "lng": 5.3787205, "expected_has_charger": None},  # 218m², 1vbo
    {"adres": "Kaasjeskruid 7, Amersfoort", "lat": 52.2023855, "lng": 5.3787699, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 8, Amersfoort", "lat": 52.2020152, "lng": 5.3788427, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Kaasjeskruid 9, Amersfoort", "lat": 52.2024302, "lng": 5.3787776, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 10, Amersfoort", "lat": 52.2020311, "lng": 5.3790063, "expected_has_charger": None},  # 210m², 1vbo
    {"adres": "Kaasjeskruid 11, Amersfoort", "lat": 52.2024748, "lng": 5.3787854, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 12, Amersfoort", "lat": 52.2020663, "lng": 5.3791232, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Kaasjeskruid 13, Amersfoort", "lat": 52.2025227, "lng": 5.3787957, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 14, Amersfoort", "lat": 52.2021093, "lng": 5.3792297, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Kaasjeskruid 15, Amersfoort", "lat": 52.2025658, "lng": 5.3788061, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 16, Amersfoort", "lat": 52.2021429, "lng": 5.3793466, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Kaasjeskruid 17, Amersfoort", "lat": 52.2026106, "lng": 5.3788114, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 18, Amersfoort", "lat": 52.2021860, "lng": 5.3796973, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Kaasjeskruid 19, Amersfoort", "lat": 52.2026536, "lng": 5.3788244, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 20, Amersfoort", "lat": 52.2021940, "lng": 5.3798116, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Kaasjeskruid 21, Amersfoort", "lat": 52.2027015, "lng": 5.3788348, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 22, Amersfoort", "lat": 52.2021988, "lng": 5.3799415, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Kaasjeskruid 23, Amersfoort", "lat": 52.2027494, "lng": 5.3788451, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 24, Amersfoort", "lat": 52.2022099, "lng": 5.3800870, "expected_has_charger": None},  # 203m², 1vbo
    {"adres": "Kaasjeskruid 25, Amersfoort", "lat": 52.2027957, "lng": 5.3788555, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Kaasjeskruid 26, Amersfoort", "lat": 52.2022579, "lng": 5.3802402, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Kaasjeskruid 27, Amersfoort", "lat": 52.2028388, "lng": 5.3788633, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Kaasjeskruid 28, Amersfoort", "lat": 52.2023169, "lng": 5.3803181, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Kaasjeskruid 29, Amersfoort", "lat": 52.2029058, "lng": 5.3791334, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Kaasjeskruid 30, Amersfoort", "lat": 52.2023840, "lng": 5.3803883, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Kaasjeskruid 31, Amersfoort", "lat": 52.2028803, "lng": 5.3791880, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 32, Amersfoort", "lat": 52.2024478, "lng": 5.3804688, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Kaasjeskruid 33, Amersfoort", "lat": 52.2028515, "lng": 5.3792477, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 35, Amersfoort", "lat": 52.2028229, "lng": 5.3792996, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 37, Amersfoort", "lat": 52.2027957, "lng": 5.3793621, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 39, Amersfoort", "lat": 52.2027638, "lng": 5.3794192, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 41, Amersfoort", "lat": 52.2027367, "lng": 5.3794816, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 43, Amersfoort", "lat": 52.2027063, "lng": 5.3795387, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 45, Amersfoort", "lat": 52.2026792, "lng": 5.3795985, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 47, Amersfoort", "lat": 52.2026505, "lng": 5.3796608, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 49, Amersfoort", "lat": 52.2026250, "lng": 5.3797128, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 51, Amersfoort", "lat": 52.2025962, "lng": 5.3797700, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kaasjeskruid 53, Amersfoort", "lat": 52.2025691, "lng": 5.3798296, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Kaasjeskruid 55, Amersfoort", "lat": 52.2025388, "lng": 5.3798895, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 57, Amersfoort", "lat": 52.2025117, "lng": 5.3799544, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kaasjeskruid 59, Amersfoort", "lat": 52.2025367, "lng": 5.3800988, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Kalmoes 1, Amersfoort", "lat": 52.2050298, "lng": 5.3766580, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 2, Amersfoort", "lat": 52.2051517, "lng": 5.3767125, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 3, Amersfoort", "lat": 52.2050422, "lng": 5.3765803, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 4, Amersfoort", "lat": 52.2051606, "lng": 5.3766234, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Kalmoes 5, Amersfoort", "lat": 52.2050580, "lng": 5.3765113, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 6, Amersfoort", "lat": 52.2051729, "lng": 5.3765401, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 7, Amersfoort", "lat": 52.2050651, "lng": 5.3764365, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 8, Amersfoort", "lat": 52.2051835, "lng": 5.3764796, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 9, Amersfoort", "lat": 52.2050757, "lng": 5.3763618, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 10, Amersfoort", "lat": 52.2051924, "lng": 5.3764278, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 11, Amersfoort", "lat": 52.2050881, "lng": 5.3762898, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 12, Amersfoort", "lat": 52.2052065, "lng": 5.3763445, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 13, Amersfoort", "lat": 52.2050969, "lng": 5.3762150, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 14, Amersfoort", "lat": 52.2052171, "lng": 5.3762697, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 15, Amersfoort", "lat": 52.2051022, "lng": 5.3761460, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 16, Amersfoort", "lat": 52.2052277, "lng": 5.3762034, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 17, Amersfoort", "lat": 52.2051181, "lng": 5.3760712, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 18, Amersfoort", "lat": 52.2052418, "lng": 5.3761257, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 19, Amersfoort", "lat": 52.2051305, "lng": 5.3759992, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 20, Amersfoort", "lat": 52.2052542, "lng": 5.3760396, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 21, Amersfoort", "lat": 52.2051358, "lng": 5.3759245, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 22, Amersfoort", "lat": 52.2052665, "lng": 5.3759849, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 23, Amersfoort", "lat": 52.2051516, "lng": 5.3758497, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 24, Amersfoort", "lat": 52.2052736, "lng": 5.3758985, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Kalmoes 25, Amersfoort", "lat": 52.2051658, "lng": 5.3757865, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kalmoes 26, Amersfoort", "lat": 52.2052807, "lng": 5.3758209, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kamsalamander 1, Amersfoort", "lat": 52.2001681, "lng": 5.3685430, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kamsalamander 2, Amersfoort", "lat": 52.2000309, "lng": 5.3682390, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Kamsalamander 3, Amersfoort", "lat": 52.2001047, "lng": 5.3685476, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kamsalamander 5, Amersfoort", "lat": 52.2000334, "lng": 5.3685461, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Kamsalamander 7, Amersfoort", "lat": 52.1999352, "lng": 5.3686067, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Kamsalamander 9, Amersfoort", "lat": 52.1998687, "lng": 5.3686049, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Kamsalamander 11, Amersfoort", "lat": 52.1997782, "lng": 5.3686265, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kamsalamander 13, Amersfoort", "lat": 52.1997150, "lng": 5.3686364, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Kamsalamander 15, Amersfoort", "lat": 52.1996307, "lng": 5.3686561, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Kamsalamander 17, Amersfoort", "lat": 52.1995573, "lng": 5.3686911, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Kattenbroekerpoort 1, Amersfoort", "lat": 52.1962288, "lng": 5.3812390, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 2, Amersfoort", "lat": 52.1960766, "lng": 5.3809651, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 3, Amersfoort", "lat": 52.1961896, "lng": 5.3812879, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 4, Amersfoort", "lat": 52.1960420, "lng": 5.3810063, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 5, Amersfoort", "lat": 52.1961550, "lng": 5.3813442, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 6, Amersfoort", "lat": 52.1960074, "lng": 5.3810703, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 7, Amersfoort", "lat": 52.1961181, "lng": 5.3813929, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 8, Amersfoort", "lat": 52.1959682, "lng": 5.3811153, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 9, Amersfoort", "lat": 52.1960812, "lng": 5.3814454, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 10, Amersfoort", "lat": 52.1959313, "lng": 5.3811678, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 11, Amersfoort", "lat": 52.1960444, "lng": 5.3815017, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 12, Amersfoort", "lat": 52.1958921, "lng": 5.3812278, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 13, Amersfoort", "lat": 52.1960052, "lng": 5.3815618, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Kattenbroekerpoort 14, Amersfoort", "lat": 52.1958598, "lng": 5.3812692, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Keulemangaarde 2, Amersfoort", "lat": 52.1946602, "lng": 5.3745495, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Keulemangaarde 4, Amersfoort", "lat": 52.1946512, "lng": 5.3746199, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Keulemangaarde 6, Amersfoort", "lat": 52.1946443, "lng": 5.3746975, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Keulemangaarde 8, Amersfoort", "lat": 52.1946375, "lng": 5.3747825, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Keulemangaarde 10, Amersfoort", "lat": 52.1946330, "lng": 5.3748565, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Keulemangaarde 12, Amersfoort", "lat": 52.1946285, "lng": 5.3749378, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Keulemangaarde 14, Amersfoort", "lat": 52.1946194, "lng": 5.3750155, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Keulemangaarde 16, Amersfoort", "lat": 52.1945808, "lng": 5.3754629, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Keulemangaarde 18, Amersfoort", "lat": 52.1945763, "lng": 5.3755406, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Keulemangaarde 20, Amersfoort", "lat": 52.1945717, "lng": 5.3756182, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Keulemangaarde 22, Amersfoort", "lat": 52.1945672, "lng": 5.3756995, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Keulemangaarde 24, Amersfoort", "lat": 52.1945672, "lng": 5.3757808, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Keulemangaarde 26, Amersfoort", "lat": 52.1945627, "lng": 5.3758622, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Kikkerbeet 1, Amersfoort", "lat": 52.2047892, "lng": 5.3735374, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Kikkerbeet 2, Amersfoort", "lat": 52.2059041, "lng": 5.3727519, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Kikkerbeet 3, Amersfoort", "lat": 52.2047874, "lng": 5.3734397, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 4, Amersfoort", "lat": 52.2059023, "lng": 5.3728296, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Kikkerbeet 5, Amersfoort", "lat": 52.2047927, "lng": 5.3733591, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 6, Amersfoort", "lat": 52.2058970, "lng": 5.3729044, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Kikkerbeet 7, Amersfoort", "lat": 52.2047909, "lng": 5.3732873, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 8, Amersfoort", "lat": 52.2058864, "lng": 5.3730539, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Kikkerbeet 9, Amersfoort", "lat": 52.2047926, "lng": 5.3731894, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 10, Amersfoort", "lat": 52.2058776, "lng": 5.3731229, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Kikkerbeet 11, Amersfoort", "lat": 52.2047926, "lng": 5.3731060, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 12, Amersfoort", "lat": 52.2058723, "lng": 5.3732093, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Kikkerbeet 13, Amersfoort", "lat": 52.2047926, "lng": 5.3730370, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 14, Amersfoort", "lat": 52.2058653, "lng": 5.3732897, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Kikkerbeet 15, Amersfoort", "lat": 52.2047891, "lng": 5.3729507, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 16, Amersfoort", "lat": 52.2058618, "lng": 5.3733588, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Kikkerbeet 17, Amersfoort", "lat": 52.2047926, "lng": 5.3728673, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 18, Amersfoort", "lat": 52.2058583, "lng": 5.3734278, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Kikkerbeet 19, Amersfoort", "lat": 52.2047979, "lng": 5.3727782, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 20, Amersfoort", "lat": 52.2058512, "lng": 5.3734853, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Kikkerbeet 21, Amersfoort", "lat": 52.2047979, "lng": 5.3727062, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 22, Amersfoort", "lat": 52.2058494, "lng": 5.3735745, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Kikkerbeet 23, Amersfoort", "lat": 52.2047997, "lng": 5.3726228, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 24, Amersfoort", "lat": 52.2058406, "lng": 5.3736522, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Kikkerbeet 25, Amersfoort", "lat": 52.2048068, "lng": 5.3725365, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 27, Amersfoort", "lat": 52.2048050, "lng": 5.3724561, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 29, Amersfoort", "lat": 52.2048031, "lng": 5.3723668, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 31, Amersfoort", "lat": 52.2048102, "lng": 5.3722777, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 33, Amersfoort", "lat": 52.2048049, "lng": 5.3722116, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 35, Amersfoort", "lat": 52.2048031, "lng": 5.3721167, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 37, Amersfoort", "lat": 52.2048049, "lng": 5.3720304, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 39, Amersfoort", "lat": 52.2048102, "lng": 5.3719527, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 41, Amersfoort", "lat": 52.2048137, "lng": 5.3718607, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kikkerbeet 43, Amersfoort", "lat": 52.2051459, "lng": 5.3717138, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Kikkerbeet 45, Amersfoort", "lat": 52.2052360, "lng": 5.3718001, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Kikkerbeet 47, Amersfoort", "lat": 52.2053244, "lng": 5.3718662, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Kikkerbeet 49, Amersfoort", "lat": 52.2054074, "lng": 5.3719438, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Kikkerbeet 51, Amersfoort", "lat": 52.2055011, "lng": 5.3720129, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Kikkerbeet 53, Amersfoort", "lat": 52.2055859, "lng": 5.3720905, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Kikkerbeet 55, Amersfoort", "lat": 52.2056743, "lng": 5.3721595, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Kikkerbeet 57, Amersfoort", "lat": 52.2057627, "lng": 5.3722400, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Kikkerbeet 59, Amersfoort", "lat": 52.2058492, "lng": 5.3723060, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Kikkerbeet 61, Amersfoort", "lat": 52.2059359, "lng": 5.3723751, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Kikkerbeet 63, Amersfoort", "lat": 52.2060277, "lng": 5.3724412, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Kikkerbeet 65, Amersfoort", "lat": 52.2061673, "lng": 5.3725735, "expected_has_charger": None},  # 205m², 1vbo
    {"adres": "Kikkerbeet 67B, Amersfoort", "lat": 52.2061803, "lng": 5.3726588, "expected_has_charger": None},  # 97m², 2vbo
    {"adres": "Kikkerbeet 69, Amersfoort", "lat": 52.2061550, "lng": 5.3727403, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 71, Amersfoort", "lat": 52.2061462, "lng": 5.3728323, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 73, Amersfoort", "lat": 52.2061444, "lng": 5.3729243, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 75, Amersfoort", "lat": 52.2061339, "lng": 5.3730251, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 77, Amersfoort", "lat": 52.2061286, "lng": 5.3731027, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 79, Amersfoort", "lat": 52.2061233, "lng": 5.3731804, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 81, Amersfoort", "lat": 52.2061127, "lng": 5.3732724, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 83, Amersfoort", "lat": 52.2061038, "lng": 5.3733530, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 85, Amersfoort", "lat": 52.2061003, "lng": 5.3734507, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Kikkerbeet 87, Amersfoort", "lat": 52.2060932, "lng": 5.3735198, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 89, Amersfoort", "lat": 52.2060809, "lng": 5.3736204, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kikkerbeet 91, Amersfoort", "lat": 52.2060791, "lng": 5.3737010, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Kleefkruid 1, Amersfoort", "lat": 52.2032413, "lng": 5.3783787, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Kleefkruid 3, Amersfoort", "lat": 52.2031675, "lng": 5.3783661, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Kleefkruid 5, Amersfoort", "lat": 52.2030879, "lng": 5.3783441, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Kleefkruid 7, Amersfoort", "lat": 52.2030121, "lng": 5.3783251, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Kleefkruid 9, Amersfoort", "lat": 52.2029344, "lng": 5.3783188, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kleefkruid 11, Amersfoort", "lat": 52.2028587, "lng": 5.3782966, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Kleefkruid 13, Amersfoort", "lat": 52.2027772, "lng": 5.3782745, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Kleefkruid 15, Amersfoort", "lat": 52.2026975, "lng": 5.3782587, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Kleefkruid 17, Amersfoort", "lat": 52.2026217, "lng": 5.3782492, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Kleefkruid 19, Amersfoort", "lat": 52.2025441, "lng": 5.3782271, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Kleefkruid 21, Amersfoort", "lat": 52.2024722, "lng": 5.3782146, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kleefkruid 23, Amersfoort", "lat": 52.2023887, "lng": 5.3781830, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Kleefkruid 25, Amersfoort", "lat": 52.2023032, "lng": 5.3781703, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Kleefkruid 27, Amersfoort", "lat": 52.2020547, "lng": 5.3781199, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Kleefkruid 29, Amersfoort", "lat": 52.2019672, "lng": 5.3781009, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kleefkruid 31, Amersfoort", "lat": 52.2018857, "lng": 5.3780851, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Kleefkruid 33, Amersfoort", "lat": 52.2018119, "lng": 5.3780630, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kleefkruid 35, Amersfoort", "lat": 52.2017265, "lng": 5.3780472, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Kleefkruid 37, Amersfoort", "lat": 52.2014701, "lng": 5.3779777, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kleefkruid 39, Amersfoort", "lat": 52.2013943, "lng": 5.3779682, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kleefkruid 41, Amersfoort", "lat": 52.2013128, "lng": 5.3779493, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Kleefkruid 43, Amersfoort", "lat": 52.2012409, "lng": 5.3779366, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Kleefkruid 45, Amersfoort", "lat": 52.2011555, "lng": 5.3779113, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Kleefkruid 47, Amersfoort", "lat": 52.2010739, "lng": 5.3778987, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Klein Kroos 1, Amersfoort", "lat": 52.2053265, "lng": 5.3745123, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 3, Amersfoort", "lat": 52.2053327, "lng": 5.3744489, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 5, Amersfoort", "lat": 52.2053344, "lng": 5.3743455, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 7, Amersfoort", "lat": 52.2053415, "lng": 5.3742937, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 9, Amersfoort", "lat": 52.2053433, "lng": 5.3742045, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 11, Amersfoort", "lat": 52.2053432, "lng": 5.3741441, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 13, Amersfoort", "lat": 52.2053521, "lng": 5.3740838, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 15, Amersfoort", "lat": 52.2053502, "lng": 5.3739946, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 17, Amersfoort", "lat": 52.2053538, "lng": 5.3739169, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 19, Amersfoort", "lat": 52.2053714, "lng": 5.3735661, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 21, Amersfoort", "lat": 52.2053732, "lng": 5.3734884, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 23, Amersfoort", "lat": 52.2053802, "lng": 5.3734078, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 25, Amersfoort", "lat": 52.2053785, "lng": 5.3733330, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Klein Kroos 27, Amersfoort", "lat": 52.2053838, "lng": 5.3732640, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 29, Amersfoort", "lat": 52.2053926, "lng": 5.3731949, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 31, Amersfoort", "lat": 52.2053926, "lng": 5.3731115, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 33, Amersfoort", "lat": 52.2053961, "lng": 5.3730454, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 35, Amersfoort", "lat": 52.2054014, "lng": 5.3729591, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 37, Amersfoort", "lat": 52.2054049, "lng": 5.3728298, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 39, Amersfoort", "lat": 52.2054084, "lng": 5.3727405, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 41, Amersfoort", "lat": 52.2054119, "lng": 5.3726744, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Klein Kroos 43, Amersfoort", "lat": 52.2054155, "lng": 5.3725938, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 45, Amersfoort", "lat": 52.2054225, "lng": 5.3725249, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 47, Amersfoort", "lat": 52.2054243, "lng": 5.3724472, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Klein Kroos 49, Amersfoort", "lat": 52.2054296, "lng": 5.3723811, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Knoopkruid 11, Amersfoort", "lat": 52.2027466, "lng": 5.3816263, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Knoopkruid 13, Amersfoort", "lat": 52.2027818, "lng": 5.3816761, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Knoopkruid 15, Amersfoort", "lat": 52.2028164, "lng": 5.3817336, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Knoopkruid 17, Amersfoort", "lat": 52.2028478, "lng": 5.3817873, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Knoopkruid 19, Amersfoort", "lat": 52.2028739, "lng": 5.3818360, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Kransvederkruid 11, Amersfoort", "lat": 52.2031207, "lng": 5.3809492, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Kransvederkruid 12, Amersfoort", "lat": 52.2029627, "lng": 5.3812533, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Kransvederkruid 13, Amersfoort", "lat": 52.2031577, "lng": 5.3809978, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Kransvederkruid 14, Amersfoort", "lat": 52.2029997, "lng": 5.3813034, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Kransvederkruid 15, Amersfoort", "lat": 52.2031957, "lng": 5.3810478, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Kransvederkruid 16, Amersfoort", "lat": 52.2030336, "lng": 5.3813486, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Kransvederkruid 17, Amersfoort", "lat": 52.2032296, "lng": 5.3810946, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Kransvederkruid 18, Amersfoort", "lat": 52.2030694, "lng": 5.3813986, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Kransvederkruid 19, Amersfoort", "lat": 52.2032645, "lng": 5.3811464, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Kransvederkruid 20, Amersfoort", "lat": 52.2031003, "lng": 5.3814488, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Kruidendreef 10, Amersfoort", "lat": 52.2022217, "lng": 5.3844403, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 12, Amersfoort", "lat": 52.2022137, "lng": 5.3843511, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Kruidendreef 14, Amersfoort", "lat": 52.2022137, "lng": 5.3842803, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Kruidendreef 16, Amersfoort", "lat": 52.2022089, "lng": 5.3842016, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Kruidendreef 18, Amersfoort", "lat": 52.2022056, "lng": 5.3841204, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 20, Amersfoort", "lat": 52.2021975, "lng": 5.3840443, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Kruidendreef 22, Amersfoort", "lat": 52.2021895, "lng": 5.3839656, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Kruidendreef 24, Amersfoort", "lat": 52.2021831, "lng": 5.3838843, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Kruidendreef 26, Amersfoort", "lat": 52.2021782, "lng": 5.3838109, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Kruidendreef 28, Amersfoort", "lat": 52.2021717, "lng": 5.3837269, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 30, Amersfoort", "lat": 52.2021670, "lng": 5.3836482, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 32, Amersfoort", "lat": 52.2021508, "lng": 5.3835354, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 34, Amersfoort", "lat": 52.2021444, "lng": 5.3834541, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Kruidendreef 36, Amersfoort", "lat": 52.2021315, "lng": 5.3833728, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Kruidendreef 38, Amersfoort", "lat": 52.2021235, "lng": 5.3832942, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 40, Amersfoort", "lat": 52.2021121, "lng": 5.3832206, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 42, Amersfoort", "lat": 52.2021040, "lng": 5.3831421, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 44, Amersfoort", "lat": 52.2020944, "lng": 5.3830581, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 46, Amersfoort", "lat": 52.2020831, "lng": 5.3829899, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 48, Amersfoort", "lat": 52.2020735, "lng": 5.3829007, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 50, Amersfoort", "lat": 52.2020654, "lng": 5.3828299, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 52, Amersfoort", "lat": 52.2020525, "lng": 5.3827618, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Kruidendreef 54, Amersfoort", "lat": 52.2020476, "lng": 5.3816707, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Kruidendreef 56, Amersfoort", "lat": 52.2020830, "lng": 5.3816076, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Kruidendreef 58, Amersfoort", "lat": 52.2021185, "lng": 5.3815552, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Kruidendreef 60, Amersfoort", "lat": 52.2021556, "lng": 5.3815080, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Kruidendreef 62, Amersfoort", "lat": 52.2021974, "lng": 5.3814607, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Kruidendreef 64, Amersfoort", "lat": 52.2022990, "lng": 5.3812037, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Kruidendreef 66, Amersfoort", "lat": 52.2023393, "lng": 5.3811408, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Kruidendreef 68, Amersfoort", "lat": 52.2023764, "lng": 5.3810909, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 70, Amersfoort", "lat": 52.2024086, "lng": 5.3810254, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 72, Amersfoort", "lat": 52.2024376, "lng": 5.3809729, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 74, Amersfoort", "lat": 52.2024762, "lng": 5.3809205, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 76, Amersfoort", "lat": 52.2025101, "lng": 5.3808627, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 78, Amersfoort", "lat": 52.2025439, "lng": 5.3808103, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 80, Amersfoort", "lat": 52.2025778, "lng": 5.3807473, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 82, Amersfoort", "lat": 52.2026084, "lng": 5.3806975, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Kruidendreef 84, Amersfoort", "lat": 52.2027438, "lng": 5.3804377, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Kruidendreef 86, Amersfoort", "lat": 52.2027776, "lng": 5.3803669, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Kruidendreef 88, Amersfoort", "lat": 52.2028050, "lng": 5.3803119, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 90, Amersfoort", "lat": 52.2028324, "lng": 5.3802489, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Kruidendreef 92, Amersfoort", "lat": 52.2028630, "lng": 5.3801886, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 94, Amersfoort", "lat": 52.2028903, "lng": 5.3801204, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Kruidendreef 96, Amersfoort", "lat": 52.2029258, "lng": 5.3800626, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Kruidendreef 98, Amersfoort", "lat": 52.2029516, "lng": 5.3799971, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Kruidendreef 100, Amersfoort", "lat": 52.2029774, "lng": 5.3799236, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Kruidendreef 102, Amersfoort", "lat": 52.2030064, "lng": 5.3798711, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Kruidendreef 104, Amersfoort", "lat": 52.2030451, "lng": 5.3797741, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Kruidendreef 106, Amersfoort", "lat": 52.2030709, "lng": 5.3797086, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 108, Amersfoort", "lat": 52.2030998, "lng": 5.3796431, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Kruidendreef 110, Amersfoort", "lat": 52.2031224, "lng": 5.3795800, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 112, Amersfoort", "lat": 52.2031482, "lng": 5.3795118, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 114, Amersfoort", "lat": 52.2031740, "lng": 5.3794410, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Kruidendreef 116, Amersfoort", "lat": 52.2031997, "lng": 5.3793702, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Kruidendreef 118, Amersfoort", "lat": 52.2032255, "lng": 5.3793047, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 120, Amersfoort", "lat": 52.2033093, "lng": 5.3790422, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Kruidendreef 122, Amersfoort", "lat": 52.2033383, "lng": 5.3789688, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Kruidendreef 124, Amersfoort", "lat": 52.2033609, "lng": 5.3789112, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 126, Amersfoort", "lat": 52.2033818, "lng": 5.3788324, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 128, Amersfoort", "lat": 52.2034011, "lng": 5.3787616, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 130, Amersfoort", "lat": 52.2034204, "lng": 5.3786961, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Kruidendreef 132, Amersfoort", "lat": 52.2034366, "lng": 5.3786148, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Kruidendreef 134, Amersfoort", "lat": 52.2034624, "lng": 5.3785440, "expected_has_charger": None},  # 97m², 1vbo
    {"adres": "Kruidendreef 136, Amersfoort", "lat": 52.2034769, "lng": 5.3784732, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Kruidendreef 138, Amersfoort", "lat": 52.2035010, "lng": 5.3783971, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Laan van Duurzaamheid 11, Amersfoort", "lat": 52.1968519, "lng": 5.3843371, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Laan van Duurzaamheid 13, Amersfoort", "lat": 52.1969210, "lng": 5.3842537, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Laan van Duurzaamheid 15, Amersfoort", "lat": 52.1969795, "lng": 5.3842108, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Laan van Duurzaamheid 17, Amersfoort", "lat": 52.1970237, "lng": 5.3841886, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Laan van Duurzaamheid 19, Amersfoort", "lat": 52.1970964, "lng": 5.3841294, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Laan van Duurzaamheid 21, Amersfoort", "lat": 52.1971584, "lng": 5.3840866, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Laan van Duurzaamheid 23, Amersfoort", "lat": 52.1972240, "lng": 5.3840615, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Laan van Duurzaamheid 25, Amersfoort", "lat": 52.1972909, "lng": 5.3840527, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Laan van Duurzaamheid 27, Amersfoort", "lat": 52.1973605, "lng": 5.3840419, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Laan van Duurzaamheid 29, Amersfoort", "lat": 52.1974250, "lng": 5.3840256, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Laan van Duurzaamheid 31, Amersfoort", "lat": 52.1974727, "lng": 5.3840343, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Laan van Duurzaamheid 33, Amersfoort", "lat": 52.1975693, "lng": 5.3840430, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Laan van Duurzaamheid 35, Amersfoort", "lat": 52.1976248, "lng": 5.3840546, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Laan van Duurzaamheid 37, Amersfoort", "lat": 52.1976892, "lng": 5.3840663, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Laan van Duurzaamheid 39, Amersfoort", "lat": 52.1977572, "lng": 5.3840807, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Laan van Duurzaamheid 41, Amersfoort", "lat": 52.1978234, "lng": 5.3840983, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Laan van Duurzaamheid 43, Amersfoort", "lat": 52.1978879, "lng": 5.3841012, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Laan van Duurzaamheid 45, Amersfoort", "lat": 52.1979468, "lng": 5.3841274, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Laan van Duurzaamheid 47, Amersfoort", "lat": 52.1980113, "lng": 5.3841419, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Laan van Duurzaamheid 49, Amersfoort", "lat": 52.1980775, "lng": 5.3841565, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Laan van Duurzaamheid 51, Amersfoort", "lat": 52.1981480, "lng": 5.3841186, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Laan van Duurzaamheid 53, Amersfoort", "lat": 52.1987662, "lng": 5.3842991, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 55, Amersfoort", "lat": 52.1988253, "lng": 5.3843108, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Laan van Duurzaamheid 57, Amersfoort", "lat": 52.1988861, "lng": 5.3843195, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 59, Amersfoort", "lat": 52.1989416, "lng": 5.3843282, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 61, Amersfoort", "lat": 52.1990007, "lng": 5.3843457, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 63, Amersfoort", "lat": 52.1990525, "lng": 5.3843516, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 65, Amersfoort", "lat": 52.1991116, "lng": 5.3843660, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Laan van Duurzaamheid 67, Amersfoort", "lat": 52.1991617, "lng": 5.3843807, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 69, Amersfoort", "lat": 52.1995087, "lng": 5.3844563, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 71, Amersfoort", "lat": 52.1995696, "lng": 5.3844738, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 73, Amersfoort", "lat": 52.1996233, "lng": 5.3844824, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 75, Amersfoort", "lat": 52.1996787, "lng": 5.3844854, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 77, Amersfoort", "lat": 52.1997432, "lng": 5.3845000, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Laan van Duurzaamheid 79, Amersfoort", "lat": 52.1998076, "lng": 5.3845145, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 81, Amersfoort", "lat": 52.1998648, "lng": 5.3845232, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 83, Amersfoort", "lat": 52.1999131, "lng": 5.3845349, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Laan van Duurzaamheid 85, Amersfoort", "lat": 52.2001449, "lng": 5.3845889, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Laan van Duurzaamheid 87, Amersfoort", "lat": 52.2002123, "lng": 5.3846037, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Laan van Duurzaamheid 89, Amersfoort", "lat": 52.2002705, "lng": 5.3846155, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Laan van Duurzaamheid 91, Amersfoort", "lat": 52.2003343, "lng": 5.3846215, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Laan van Duurzaamheid 93, Amersfoort", "lat": 52.2003962, "lng": 5.3846392, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Laan van Duurzaamheid 95, Amersfoort", "lat": 52.2004581, "lng": 5.3846510, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Laan van Duurzaamheid 97, Amersfoort", "lat": 52.2005201, "lng": 5.3846689, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Laan van Duurzaamheid 99, Amersfoort", "lat": 52.2005802, "lng": 5.3846778, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Laan van Duurzaamheid 101, Amersfoort", "lat": 52.2006421, "lng": 5.3846897, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Laan van Duurzaamheid 103, Amersfoort", "lat": 52.2007021, "lng": 5.3847074, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Laan van Duurzaamheid 105, Amersfoort", "lat": 52.2007641, "lng": 5.3847223, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Laan van Duurzaamheid 107, Amersfoort", "lat": 52.2008242, "lng": 5.3847223, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Laan van Duurzaamheid 109, Amersfoort", "lat": 52.2008898, "lng": 5.3847400, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Laan van Duurzaamheid 111, Amersfoort", "lat": 52.2009536, "lng": 5.3847578, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Laan van Duurzaamheid 113, Amersfoort", "lat": 52.2010136, "lng": 5.3847756, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Laan van Duurzaamheid 115, Amersfoort", "lat": 52.2010719, "lng": 5.3847875, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Laan van Duurzaamheid 117, Amersfoort", "lat": 52.2011338, "lng": 5.3848052, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Laan van Duurzaamheid 119, Amersfoort", "lat": 52.2014070, "lng": 5.3848526, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Laan van Duurzaamheid 121, Amersfoort", "lat": 52.2014634, "lng": 5.3848556, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Laan van Duurzaamheid 123, Amersfoort", "lat": 52.2015236, "lng": 5.3848556, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Laan van Duurzaamheid 125, Amersfoort", "lat": 52.2015819, "lng": 5.3848585, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Laan van Duurzaamheid 127, Amersfoort", "lat": 52.2016456, "lng": 5.3848585, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Laan van Duurzaamheid 129, Amersfoort", "lat": 52.2017075, "lng": 5.3848525, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Laan van Duurzaamheid 131, Amersfoort", "lat": 52.2017676, "lng": 5.3848438, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Laan van Duurzaamheid 133, Amersfoort", "lat": 52.2018295, "lng": 5.3848378, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Laan van Duurzaamheid 135, Amersfoort", "lat": 52.2018914, "lng": 5.3848288, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Laan van Duurzaamheid 137, Amersfoort", "lat": 52.2019534, "lng": 5.3848170, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Laan van Duurzaamheid 139, Amersfoort", "lat": 52.2020117, "lng": 5.3847993, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Lemoengaarde 2, Amersfoort", "lat": 52.1969792, "lng": 5.3729958, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Lemoengaarde 4, Amersfoort", "lat": 52.1969582, "lng": 5.3730678, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Lemoengaarde 6, Amersfoort", "lat": 52.1969393, "lng": 5.3731430, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 8, Amersfoort", "lat": 52.1969183, "lng": 5.3732150, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 10, Amersfoort", "lat": 52.1968993, "lng": 5.3732834, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 12, Amersfoort", "lat": 52.1968783, "lng": 5.3733621, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 14, Amersfoort", "lat": 52.1968594, "lng": 5.3734339, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 16, Amersfoort", "lat": 52.1968405, "lng": 5.3735161, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 18, Amersfoort", "lat": 52.1968237, "lng": 5.3735913, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 20, Amersfoort", "lat": 52.1968111, "lng": 5.3736598, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Lemoengaarde 22, Amersfoort", "lat": 52.1967942, "lng": 5.3737317, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 24, Amersfoort", "lat": 52.1967774, "lng": 5.3738138, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 26, Amersfoort", "lat": 52.1967649, "lng": 5.3738925, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Lemoengaarde 28, Amersfoort", "lat": 52.1967480, "lng": 5.3739645, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Leverkruid 11, Amersfoort", "lat": 52.2034508, "lng": 5.3802306, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Leverkruid 12, Amersfoort", "lat": 52.2033181, "lng": 5.3805472, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Leverkruid 13, Amersfoort", "lat": 52.2034890, "lng": 5.3802758, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Leverkruid 14, Amersfoort", "lat": 52.2033580, "lng": 5.3805852, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Leverkruid 15, Amersfoort", "lat": 52.2035289, "lng": 5.3803127, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Leverkruid 16, Amersfoort", "lat": 52.2033927, "lng": 5.3806249, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Leverkruid 17, Amersfoort", "lat": 52.2035680, "lng": 5.3803564, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Leverkruid 18, Amersfoort", "lat": 52.2034309, "lng": 5.3806701, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Leverkruid 19, Amersfoort", "lat": 52.2036096, "lng": 5.3803931, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Leverkruid 20, Amersfoort", "lat": 52.2034648, "lng": 5.3807125, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Limburgse Bellefleur 2, Amersfoort", "lat": 52.1948899, "lng": 5.3728286, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Limburgse Bellefleur 4, Amersfoort", "lat": 52.1948805, "lng": 5.3729057, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Limburgse Bellefleur 6, Amersfoort", "lat": 52.1948710, "lng": 5.3729737, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Limburgse Bellefleur 8, Amersfoort", "lat": 52.1948577, "lng": 5.3730569, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Limburgse Bellefleur 10, Amersfoort", "lat": 52.1948464, "lng": 5.3731341, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Limburgse Bellefleur 12, Amersfoort", "lat": 52.1948331, "lng": 5.3732051, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Limburgse Bellefleur 14, Amersfoort", "lat": 52.1948198, "lng": 5.3732884, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Lisdodde 1, Amersfoort", "lat": 52.2048788, "lng": 5.3776674, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 2, Amersfoort", "lat": 52.2049875, "lng": 5.3777135, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 3, Amersfoort", "lat": 52.2048903, "lng": 5.3775899, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 4, Amersfoort", "lat": 52.2050034, "lng": 5.3776358, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 5, Amersfoort", "lat": 52.2048991, "lng": 5.3775063, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 6, Amersfoort", "lat": 52.2050140, "lng": 5.3775640, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 7, Amersfoort", "lat": 52.2049132, "lng": 5.3774432, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 8, Amersfoort", "lat": 52.2050228, "lng": 5.3775006, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 9, Amersfoort", "lat": 52.2049185, "lng": 5.3773712, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 10, Amersfoort", "lat": 52.2050352, "lng": 5.3774172, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 11, Amersfoort", "lat": 52.2049309, "lng": 5.3773051, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 12, Amersfoort", "lat": 52.2050476, "lng": 5.3773511, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 13, Amersfoort", "lat": 52.2049450, "lng": 5.3772303, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 14, Amersfoort", "lat": 52.2050564, "lng": 5.3772763, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 15, Amersfoort", "lat": 52.2049538, "lng": 5.3771526, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 16, Amersfoort", "lat": 52.2050705, "lng": 5.3772073, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 17, Amersfoort", "lat": 52.2049609, "lng": 5.3770922, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Lisdodde 18, Amersfoort", "lat": 52.2050776, "lng": 5.3771382, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Longkruid 11, Amersfoort", "lat": 52.2037624, "lng": 5.3793745, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Longkruid 12, Amersfoort", "lat": 52.2036261, "lng": 5.3797955, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Longkruid 13, Amersfoort", "lat": 52.2038049, "lng": 5.3794239, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Longkruid 14, Amersfoort", "lat": 52.2036618, "lng": 5.3798238, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Longkruid 15, Amersfoort", "lat": 52.2038457, "lng": 5.3794621, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Longkruid 16, Amersfoort", "lat": 52.2037008, "lng": 5.3798647, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Longkruid 17, Amersfoort", "lat": 52.2038831, "lng": 5.3794946, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Longkruid 18, Amersfoort", "lat": 52.2037399, "lng": 5.3799014, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Longkruid 19, Amersfoort", "lat": 52.2039204, "lng": 5.3795313, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Longkruid 20, Amersfoort", "lat": 52.2037824, "lng": 5.3799354, "expected_has_charger": None},  # 83m², 1vbo
    {"adres": "Maanglans 2, Amersfoort", "lat": 52.1983088, "lng": 5.3762809, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 4, Amersfoort", "lat": 52.1982850, "lng": 5.3763422, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 6, Amersfoort", "lat": 52.1982438, "lng": 5.3763951, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 8, Amersfoort", "lat": 52.1982113, "lng": 5.3764481, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 10, Amersfoort", "lat": 52.1981736, "lng": 5.3765038, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 12, Amersfoort", "lat": 52.1981411, "lng": 5.3765540, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 14, Amersfoort", "lat": 52.1981034, "lng": 5.3766070, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 16, Amersfoort", "lat": 52.1980709, "lng": 5.3766571, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 18, Amersfoort", "lat": 52.1979990, "lng": 5.3766934, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Maanglans 20, Amersfoort", "lat": 52.1979973, "lng": 5.3768160, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Maanglans 22, Amersfoort", "lat": 52.1980658, "lng": 5.3768495, "expected_has_charger": None},  # 147m², 2vbo
    {"adres": "Maanglans 24, Amersfoort", "lat": 52.1980915, "lng": 5.3769052, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 26, Amersfoort", "lat": 52.1981291, "lng": 5.3769693, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 28, Amersfoort", "lat": 52.1981600, "lng": 5.3770333, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 30, Amersfoort", "lat": 52.1981891, "lng": 5.3770890, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 32, Amersfoort", "lat": 52.1982165, "lng": 5.3771503, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 34, Amersfoort", "lat": 52.1982525, "lng": 5.3772145, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 36, Amersfoort", "lat": 52.1982816, "lng": 5.3772813, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 38, Amersfoort", "lat": 52.1983159, "lng": 5.3773398, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 40, Amersfoort", "lat": 52.1983484, "lng": 5.3773956, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 42, Amersfoort", "lat": 52.1983792, "lng": 5.3774541, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 44, Amersfoort", "lat": 52.1984100, "lng": 5.3775181, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 46, Amersfoort", "lat": 52.1984443, "lng": 5.3775766, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Maanglans 48, Amersfoort", "lat": 52.1984768, "lng": 5.3776296, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Mantetgaarde 2, Amersfoort", "lat": 52.1965905, "lng": 5.3752109, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Mantetgaarde 4, Amersfoort", "lat": 52.1965840, "lng": 5.3752952, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Mantetgaarde 6, Amersfoort", "lat": 52.1965754, "lng": 5.3753724, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Mantetgaarde 8, Amersfoort", "lat": 52.1965711, "lng": 5.3754461, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Mantetgaarde 10, Amersfoort", "lat": 52.1965646, "lng": 5.3755339, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Mantetgaarde 12, Amersfoort", "lat": 52.1965581, "lng": 5.3756148, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Mantetgaarde 14, Amersfoort", "lat": 52.1965517, "lng": 5.3756920, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Mantetgaarde 16, Amersfoort", "lat": 52.1965474, "lng": 5.3757622, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Mantetgaarde 18, Amersfoort", "lat": 52.1965452, "lng": 5.3758465, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Mantetgaarde 20, Amersfoort", "lat": 52.1965366, "lng": 5.3759272, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Mantetgaarde 22, Amersfoort", "lat": 52.1965344, "lng": 5.3760115, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Mantetgaarde 24, Amersfoort", "lat": 52.1965345, "lng": 5.3760887, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Mattenbies 1, Amersfoort", "lat": 52.2047223, "lng": 5.3766724, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Mattenbies 2, Amersfoort", "lat": 52.2044555, "lng": 5.3766293, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Mattenbies 3, Amersfoort", "lat": 52.2047082, "lng": 5.3767558, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Mattenbies 4, Amersfoort", "lat": 52.2044396, "lng": 5.3767357, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 5, Amersfoort", "lat": 52.2046993, "lng": 5.3768191, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 6, Amersfoort", "lat": 52.2044255, "lng": 5.3768278, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 7, Amersfoort", "lat": 52.2046888, "lng": 5.3768910, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 8, Amersfoort", "lat": 52.2044167, "lng": 5.3769313, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Mattenbies 9, Amersfoort", "lat": 52.2046799, "lng": 5.3769686, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Mattenbies 10, Amersfoort", "lat": 52.2044061, "lng": 5.3770291, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 11, Amersfoort", "lat": 52.2046658, "lng": 5.3770318, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Mattenbies 12, Amersfoort", "lat": 52.2043866, "lng": 5.3771039, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Mattenbies 13, Amersfoort", "lat": 52.2046570, "lng": 5.3771154, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Mattenbies 14, Amersfoort", "lat": 52.2043725, "lng": 5.3771988, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 15, Amersfoort", "lat": 52.2046411, "lng": 5.3771786, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 16, Amersfoort", "lat": 52.2043531, "lng": 5.3772995, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 17, Amersfoort", "lat": 52.2046287, "lng": 5.3772592, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Mattenbies 18, Amersfoort", "lat": 52.2043443, "lng": 5.3773972, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 19, Amersfoort", "lat": 52.2046181, "lng": 5.3773310, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Mattenbies 20, Amersfoort", "lat": 52.2043301, "lng": 5.3774835, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 21, Amersfoort", "lat": 52.2046057, "lng": 5.3774058, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Mattenbies 22, Amersfoort", "lat": 52.2043142, "lng": 5.3775814, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 23, Amersfoort", "lat": 52.2045952, "lng": 5.3774662, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 24, Amersfoort", "lat": 52.2043019, "lng": 5.3776705, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 25, Amersfoort", "lat": 52.2045793, "lng": 5.3775496, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Mattenbies 26, Amersfoort", "lat": 52.2042860, "lng": 5.3777654, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 27, Amersfoort", "lat": 52.2052800, "lng": 5.3778343, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 28, Amersfoort", "lat": 52.2042683, "lng": 5.3778631, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Mattenbies 29, Amersfoort", "lat": 52.2052959, "lng": 5.3777595, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 30, Amersfoort", "lat": 52.2044662, "lng": 5.3778689, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Mattenbies 31, Amersfoort", "lat": 52.2053065, "lng": 5.3776789, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Mattenbies 32, Amersfoort", "lat": 52.2045298, "lng": 5.3778948, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 33, Amersfoort", "lat": 52.2053224, "lng": 5.3776071, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Mattenbies 34, Amersfoort", "lat": 52.2045820, "lng": 5.3779178, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 35, Amersfoort", "lat": 52.2053259, "lng": 5.3775380, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 36, Amersfoort", "lat": 52.2046456, "lng": 5.3779293, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 37, Amersfoort", "lat": 52.2053436, "lng": 5.3774689, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 38, Amersfoort", "lat": 52.2047092, "lng": 5.3779695, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 39, Amersfoort", "lat": 52.2053542, "lng": 5.3773826, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 40, Amersfoort", "lat": 52.2047675, "lng": 5.3779868, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 41, Amersfoort", "lat": 52.2053630, "lng": 5.3773308, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 42, Amersfoort", "lat": 52.2048205, "lng": 5.3780068, "expected_has_charger": None},  # 188m², 1vbo
    {"adres": "Mattenbies 43, Amersfoort", "lat": 52.2053736, "lng": 5.3772418, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 44, Amersfoort", "lat": 52.2048841, "lng": 5.3780386, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 45, Amersfoort", "lat": 52.2053842, "lng": 5.3771784, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Mattenbies 46, Amersfoort", "lat": 52.2049407, "lng": 5.3780615, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 47, Amersfoort", "lat": 52.2053948, "lng": 5.3771007, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Mattenbies 48, Amersfoort", "lat": 52.2049955, "lng": 5.3780788, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 49, Amersfoort", "lat": 52.2054089, "lng": 5.3770289, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Mattenbies 50, Amersfoort", "lat": 52.2050591, "lng": 5.3781104, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Mattenbies 51, Amersfoort", "lat": 52.2054177, "lng": 5.3769541, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Mattenbies 52, Amersfoort", "lat": 52.2051068, "lng": 5.3781276, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 54, Amersfoort", "lat": 52.2051651, "lng": 5.3781535, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 56, Amersfoort", "lat": 52.2052288, "lng": 5.3781737, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Mattenbies 58, Amersfoort", "lat": 52.2052853, "lng": 5.3781937, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 60, Amersfoort", "lat": 52.2053365, "lng": 5.3782282, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 62, Amersfoort", "lat": 52.2053931, "lng": 5.3782484, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Mattenbies 64, Amersfoort", "lat": 52.2054479, "lng": 5.3782829, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Mattenbies 66, Amersfoort", "lat": 52.2055079, "lng": 5.3782972, "expected_has_charger": None},  # 235m², 1vbo
    {"adres": "Mattenbies 68, Amersfoort", "lat": 52.2055097, "lng": 5.3779981, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Mattenbies 70, Amersfoort", "lat": 52.2055344, "lng": 5.3778658, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Mattenbies 72, Amersfoort", "lat": 52.2055538, "lng": 5.3777336, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Mattenbies 74, Amersfoort", "lat": 52.2055715, "lng": 5.3776127, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Mattenbies 76, Amersfoort", "lat": 52.2055962, "lng": 5.3774862, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Mattenbies 78, Amersfoort", "lat": 52.2056156, "lng": 5.3773855, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Mattenbies 80, Amersfoort", "lat": 52.2056333, "lng": 5.3772272, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Mattenbies 82, Amersfoort", "lat": 52.2056474, "lng": 5.3771266, "expected_has_charger": None},  # 202m², 1vbo
    {"adres": "Meerval 2, Amersfoort", "lat": 52.2031768, "lng": 5.3689023, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Meerval 4, Amersfoort", "lat": 52.2032248, "lng": 5.3689396, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Meerval 6, Amersfoort", "lat": 52.2032614, "lng": 5.3689804, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Meerval 8, Amersfoort", "lat": 52.2033004, "lng": 5.3690363, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Meerval 10, Amersfoort", "lat": 52.2033392, "lng": 5.3690809, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Meerval 12, Amersfoort", "lat": 52.2033758, "lng": 5.3691293, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Meerval 14, Amersfoort", "lat": 52.2034169, "lng": 5.3691739, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Meerval 16, Amersfoort", "lat": 52.2034650, "lng": 5.3692037, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Moerasslak 1, Amersfoort", "lat": 52.2018510, "lng": 5.3698543, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 2, Amersfoort", "lat": 52.2018405, "lng": 5.3702109, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Moerasslak 3, Amersfoort", "lat": 52.2018916, "lng": 5.3698629, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 4, Amersfoort", "lat": 52.2018811, "lng": 5.3702195, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Moerasslak 5, Amersfoort", "lat": 52.2019464, "lng": 5.3698715, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 6, Amersfoort", "lat": 52.2019288, "lng": 5.3702109, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Moerasslak 7, Amersfoort", "lat": 52.2019906, "lng": 5.3698917, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 8, Amersfoort", "lat": 52.2019747, "lng": 5.3702079, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "Moerasslak 9, Amersfoort", "lat": 52.2020365, "lng": 5.3698917, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 10, Amersfoort", "lat": 52.2020189, "lng": 5.3702195, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "Moerasslak 11, Amersfoort", "lat": 52.2020842, "lng": 5.3699060, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 12, Amersfoort", "lat": 52.2020754, "lng": 5.3702108, "expected_has_charger": None},  # 93m², 1vbo
    {"adres": "Moerasslak 13, Amersfoort", "lat": 52.2021249, "lng": 5.3699232, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 14, Amersfoort", "lat": 52.2021161, "lng": 5.3702108, "expected_has_charger": None},  # 94m², 1vbo
    {"adres": "Moerasslak 15, Amersfoort", "lat": 52.2021761, "lng": 5.3699203, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 16, Amersfoort", "lat": 52.2021655, "lng": 5.3702137, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Moerasslak 17, Amersfoort", "lat": 52.2022167, "lng": 5.3699175, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 18, Amersfoort", "lat": 52.2022098, "lng": 5.3702108, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Moerasslak 19, Amersfoort", "lat": 52.2022645, "lng": 5.3699261, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 20, Amersfoort", "lat": 52.2022522, "lng": 5.3702223, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Moerasslak 21, Amersfoort", "lat": 52.2023087, "lng": 5.3699231, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Moerasslak 22, Amersfoort", "lat": 52.2022998, "lng": 5.3702223, "expected_has_charger": None},  # 89m², 1vbo
    {"adres": "Moerasslak 23, Amersfoort", "lat": 52.2023510, "lng": 5.3699461, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Moerasslak 24, Amersfoort", "lat": 52.2023423, "lng": 5.3702280, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Moerasslak 25, Amersfoort", "lat": 52.2025066, "lng": 5.3700323, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Moerasslak 26, Amersfoort", "lat": 52.2025013, "lng": 5.3701877, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Nagelkruid 1, Amersfoort", "lat": 52.2044325, "lng": 5.3791244, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Nagelkruid 2, Amersfoort", "lat": 52.2045982, "lng": 5.3792190, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Nagelkruid 3, Amersfoort", "lat": 52.2044377, "lng": 5.3790508, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "Nagelkruid 4, Amersfoort", "lat": 52.2046373, "lng": 5.3791554, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Nagelkruid 5, Amersfoort", "lat": 52.2044377, "lng": 5.3789689, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Nagelkruid 6, Amersfoort", "lat": 52.2046651, "lng": 5.3790904, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Nagelkruid 7, Amersfoort", "lat": 52.2044394, "lng": 5.3788884, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Nagelkruid 8, Amersfoort", "lat": 52.2046955, "lng": 5.3790310, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Nagelkruid 9, Amersfoort", "lat": 52.2044455, "lng": 5.3788135, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Nagelkruid 10, Amersfoort", "lat": 52.2047223, "lng": 5.3789675, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Nagelkruid 11, Amersfoort", "lat": 52.2044489, "lng": 5.3787329, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Nagelkruid 12, Amersfoort", "lat": 52.2047510, "lng": 5.3789011, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Nagelkruid 13, Amersfoort", "lat": 52.2044550, "lng": 5.3786497, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Nagelkruid 14, Amersfoort", "lat": 52.2047806, "lng": 5.3788347, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Nagelkruid 16, Amersfoort", "lat": 52.2047996, "lng": 5.3787655, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Nieuwlandsedreef 2, Amersfoort", "lat": 52.2026786, "lng": 5.3852429, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Nieuwlandsedreef 3, Amersfoort", "lat": 52.2029677, "lng": 5.3845960, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Nieuwlandsedreef 4, Amersfoort", "lat": 52.2027158, "lng": 5.3851534, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Nieuwlandsedreef 5, Amersfoort", "lat": 52.2030529, "lng": 5.3845586, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Nieuwlandsedreef 6, Amersfoort", "lat": 52.2027850, "lng": 5.3850813, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Nieuwlandsedreef 7, Amersfoort", "lat": 52.2032693, "lng": 5.3844777, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Nieuwlandsedreef 8, Amersfoort", "lat": 52.2028578, "lng": 5.3850552, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Nieuwlandsedreef 9, Amersfoort", "lat": 52.2033439, "lng": 5.3844489, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Nieuwlandsedreef 10, Amersfoort", "lat": 52.2029837, "lng": 5.3850149, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Nieuwlandsedreef 11, Amersfoort", "lat": 52.2035852, "lng": 5.3842871, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Nieuwlandsedreef 12, Amersfoort", "lat": 52.2030316, "lng": 5.3849917, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 13, Amersfoort", "lat": 52.2036420, "lng": 5.3842322, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Nieuwlandsedreef 14, Amersfoort", "lat": 52.2030777, "lng": 5.3849743, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 15, Amersfoort", "lat": 52.2038744, "lng": 5.3840098, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Nieuwlandsedreef 16, Amersfoort", "lat": 52.2031274, "lng": 5.3849542, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 17, Amersfoort", "lat": 52.2039347, "lng": 5.3839521, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Nieuwlandsedreef 18, Amersfoort", "lat": 52.2031736, "lng": 5.3849369, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 19, Amersfoort", "lat": 52.2041369, "lng": 5.3836691, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Nieuwlandsedreef 20, Amersfoort", "lat": 52.2032198, "lng": 5.3849167, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Nieuwlandsedreef 21, Amersfoort", "lat": 52.2041866, "lng": 5.3835825, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Nieuwlandsedreef 22, Amersfoort", "lat": 52.2033226, "lng": 5.3848848, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Nieuwlandsedreef 23, Amersfoort", "lat": 52.2043338, "lng": 5.3833312, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Nieuwlandsedreef 24, Amersfoort", "lat": 52.2033705, "lng": 5.3848646, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 25, Amersfoort", "lat": 52.2043871, "lng": 5.3832301, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Nieuwlandsedreef 26, Amersfoort", "lat": 52.2034184, "lng": 5.3848473, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 27, Amersfoort", "lat": 52.2045823, "lng": 5.3831060, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Nieuwlandsedreef 28, Amersfoort", "lat": 52.2034663, "lng": 5.3848329, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 29, Amersfoort", "lat": 52.2046036, "lng": 5.3830539, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 30, Amersfoort", "lat": 52.2035142, "lng": 5.3848127, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 31, Amersfoort", "lat": 52.2046497, "lng": 5.3829154, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 33, Amersfoort", "lat": 52.2046674, "lng": 5.3828547, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 35, Amersfoort", "lat": 52.2047171, "lng": 5.3827248, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 37, Amersfoort", "lat": 52.2047366, "lng": 5.3826670, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 39, Amersfoort", "lat": 52.2047810, "lng": 5.3825312, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 41, Amersfoort", "lat": 52.2048005, "lng": 5.3824764, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 43, Amersfoort", "lat": 52.2048519, "lng": 5.3823032, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 45, Amersfoort", "lat": 52.2048714, "lng": 5.3822338, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 47, Amersfoort", "lat": 52.2049122, "lng": 5.3820981, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 49, Amersfoort", "lat": 52.2049282, "lng": 5.3820317, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 51, Amersfoort", "lat": 52.2049761, "lng": 5.3819017, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 53, Amersfoort", "lat": 52.2049903, "lng": 5.3818383, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 55, Amersfoort", "lat": 52.2050293, "lng": 5.3816909, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 57, Amersfoort", "lat": 52.2050452, "lng": 5.3816361, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 59, Amersfoort", "lat": 52.2050896, "lng": 5.3814599, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 61, Amersfoort", "lat": 52.2051055, "lng": 5.3813906, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 63, Amersfoort", "lat": 52.2051411, "lng": 5.3812519, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 65, Amersfoort", "lat": 52.2051570, "lng": 5.3811913, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 67, Amersfoort", "lat": 52.2051871, "lng": 5.3810411, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 69, Amersfoort", "lat": 52.2051995, "lng": 5.3809805, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 71, Amersfoort", "lat": 52.2052350, "lng": 5.3808361, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 73, Amersfoort", "lat": 52.2052510, "lng": 5.3807726, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 75, Amersfoort", "lat": 52.2052900, "lng": 5.3805820, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 77, Amersfoort", "lat": 52.2052953, "lng": 5.3805156, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 79, Amersfoort", "lat": 52.2053290, "lng": 5.3803740, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 81, Amersfoort", "lat": 52.2053379, "lng": 5.3803076, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 83, Amersfoort", "lat": 52.2053698, "lng": 5.3801546, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 85, Amersfoort", "lat": 52.2053823, "lng": 5.3800940, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 87, Amersfoort", "lat": 52.2054089, "lng": 5.3799467, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 89, Amersfoort", "lat": 52.2054177, "lng": 5.3798860, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Nieuwlandsedreef 91, Amersfoort", "lat": 52.2056228, "lng": 5.3790996, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 93, Amersfoort", "lat": 52.2056582, "lng": 5.3789903, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 95, Amersfoort", "lat": 52.2056882, "lng": 5.3788954, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 97, Amersfoort", "lat": 52.2057183, "lng": 5.3787861, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 99, Amersfoort", "lat": 52.2057412, "lng": 5.3786768, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 101, Amersfoort", "lat": 52.2057607, "lng": 5.3785734, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 103, Amersfoort", "lat": 52.2057801, "lng": 5.3784639, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Nieuwlandsedreef 105, Amersfoort", "lat": 52.2058030, "lng": 5.3783576, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 107, Amersfoort", "lat": 52.2058225, "lng": 5.3782512, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 109, Amersfoort", "lat": 52.2058472, "lng": 5.3781563, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 111, Amersfoort", "lat": 52.2058701, "lng": 5.3780383, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 113, Amersfoort", "lat": 52.2058878, "lng": 5.3779520, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 115, Amersfoort", "lat": 52.2059072, "lng": 5.3778485, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 117, Amersfoort", "lat": 52.2059267, "lng": 5.3777392, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 119, Amersfoort", "lat": 52.2059461, "lng": 5.3776499, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 121, Amersfoort", "lat": 52.2059655, "lng": 5.3775292, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 123, Amersfoort", "lat": 52.2059902, "lng": 5.3774227, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 125, Amersfoort", "lat": 52.2060044, "lng": 5.3773250, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 127, Amersfoort", "lat": 52.2060273, "lng": 5.3772099, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 129, Amersfoort", "lat": 52.2060503, "lng": 5.3770574, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Nieuwlandsedreef 131, Amersfoort", "lat": 52.2060732, "lng": 5.3769395, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 133, Amersfoort", "lat": 52.2060874, "lng": 5.3768332, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 135, Amersfoort", "lat": 52.2061068, "lng": 5.3767296, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 137, Amersfoort", "lat": 52.2061227, "lng": 5.3766117, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 139, Amersfoort", "lat": 52.2061386, "lng": 5.3765340, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Nieuwlandsedreef 141, Amersfoort", "lat": 52.2061562, "lng": 5.3764103, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Nieuwlandsedreef 143, Amersfoort", "lat": 52.2061704, "lng": 5.3763011, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 145, Amersfoort", "lat": 52.2061916, "lng": 5.3761889, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 147, Amersfoort", "lat": 52.2062057, "lng": 5.3760882, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 149, Amersfoort", "lat": 52.2062181, "lng": 5.3759846, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 151, Amersfoort", "lat": 52.2062375, "lng": 5.3758724, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 153, Amersfoort", "lat": 52.2062481, "lng": 5.3757747, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 155, Amersfoort", "lat": 52.2062657, "lng": 5.3756481, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 157, Amersfoort", "lat": 52.2062834, "lng": 5.3755445, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandsedreef 159, Amersfoort", "lat": 52.2063293, "lng": 5.3751994, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Nieuwlandsedreef 161, Amersfoort", "lat": 52.2063399, "lng": 5.3750959, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 163, Amersfoort", "lat": 52.2063532, "lng": 5.3749895, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 165, Amersfoort", "lat": 52.2063673, "lng": 5.3748716, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 167, Amersfoort", "lat": 52.2063814, "lng": 5.3747737, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Nieuwlandsedreef 169, Amersfoort", "lat": 52.2063973, "lng": 5.3746501, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Nieuwlandsedreef 171, Amersfoort", "lat": 52.2064079, "lng": 5.3745665, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Nieuwlandsedreef 173, Amersfoort", "lat": 52.2064185, "lng": 5.3744486, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Nieuwlandsedreef 175, Amersfoort", "lat": 52.2064291, "lng": 5.3743366, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 177, Amersfoort", "lat": 52.2064468, "lng": 5.3742359, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 179, Amersfoort", "lat": 52.2064582, "lng": 5.3741323, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 181, Amersfoort", "lat": 52.2064706, "lng": 5.3740258, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Nieuwlandsedreef 183, Amersfoort", "lat": 52.2064847, "lng": 5.3738332, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Nieuwlandsedreef 185, Amersfoort", "lat": 52.2064936, "lng": 5.3737296, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Nieuwlandsedreef 187, Amersfoort", "lat": 52.2065059, "lng": 5.3735973, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 189, Amersfoort", "lat": 52.2065147, "lng": 5.3734823, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 191, Amersfoort", "lat": 52.2065252, "lng": 5.3733874, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 193, Amersfoort", "lat": 52.2065270, "lng": 5.3732781, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 195, Amersfoort", "lat": 52.2065411, "lng": 5.3731745, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 197, Amersfoort", "lat": 52.2065447, "lng": 5.3730537, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 199, Amersfoort", "lat": 52.2065553, "lng": 5.3729473, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Nieuwlandsedreef 201, Amersfoort", "lat": 52.2065641, "lng": 5.3728092, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Nieuwlandseweg 1, Amersfoort", "lat": 52.1999522, "lng": 5.3839381, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Nieuwlandseweg 3, Amersfoort", "lat": 52.1999627, "lng": 5.3838527, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Nieuwlandseweg 5, Amersfoort", "lat": 52.1999714, "lng": 5.3837790, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "Nieuwlandseweg 7, Amersfoort", "lat": 52.1999783, "lng": 5.3836905, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Nieuwlandseweg 9, Amersfoort", "lat": 52.1999818, "lng": 5.3836197, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Nieuwlandseweg 10, Amersfoort", "lat": 52.2002169, "lng": 5.3841411, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Nieuwlandseweg 11, Amersfoort", "lat": 52.1999906, "lng": 5.3835341, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Nieuwlandseweg 12, Amersfoort", "lat": 52.2002241, "lng": 5.3840598, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Nieuwlandseweg 13, Amersfoort", "lat": 52.1999960, "lng": 5.3834546, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Nieuwlandseweg 14, Amersfoort", "lat": 52.2002348, "lng": 5.3839757, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Nieuwlandseweg 15, Amersfoort", "lat": 52.2000029, "lng": 5.3833778, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Nieuwlandseweg 16, Amersfoort", "lat": 52.2002437, "lng": 5.3839002, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Nieuwlandseweg 17, Amersfoort", "lat": 52.2000099, "lng": 5.3833040, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Nieuwlandseweg 18, Amersfoort", "lat": 52.2002526, "lng": 5.3838277, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Nieuwlandseweg 19, Amersfoort", "lat": 52.2000151, "lng": 5.3832444, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Nieuwlandseweg 20, Amersfoort", "lat": 52.2002598, "lng": 5.3837464, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Nieuwlandseweg 22, Amersfoort", "lat": 52.2002632, "lng": 5.3836652, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Nieuwlandseweg 23, Amersfoort", "lat": 52.2002280, "lng": 5.3807647, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Nieuwlandseweg 24, Amersfoort", "lat": 52.2002704, "lng": 5.3835925, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Nieuwlandseweg 25, Amersfoort", "lat": 52.2002377, "lng": 5.3806724, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Nieuwlandseweg 26, Amersfoort", "lat": 52.2002775, "lng": 5.3835228, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Nieuwlandseweg 27, Amersfoort", "lat": 52.2002507, "lng": 5.3804828, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Nieuwlandseweg 28, Amersfoort", "lat": 52.2002846, "lng": 5.3834300, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Nieuwlandseweg 29, Amersfoort", "lat": 52.2002588, "lng": 5.3803853, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Nieuwlandseweg 30, Amersfoort", "lat": 52.2002900, "lng": 5.3833545, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Nieuwlandseweg 31, Amersfoort", "lat": 52.2002776, "lng": 5.3802182, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Nieuwlandseweg 32, Amersfoort", "lat": 52.2002971, "lng": 5.3832762, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Nieuwlandseweg 33, Amersfoort", "lat": 52.2002831, "lng": 5.3801493, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Nieuwlandseweg 35, Amersfoort", "lat": 52.2002928, "lng": 5.3799662, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Nieuwlandseweg 37, Amersfoort", "lat": 52.2002947, "lng": 5.3798749, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Nieuwlandseweg 38, Amersfoort", "lat": 52.2004813, "lng": 5.3804871, "expected_has_charger": None},  # 341m², 1vbo
    {"adres": "Nieuwlandseweg 40, Amersfoort", "lat": 52.2005610, "lng": 5.3801676, "expected_has_charger": None},  # 257m², 1vbo
    {"adres": "Nieuwlandseweg 42, Amersfoort", "lat": 52.2005698, "lng": 5.3799906, "expected_has_charger": None},  # 267m², 1vbo
    {"adres": "Nieuwlandseweg 44, Amersfoort", "lat": 52.2005960, "lng": 5.3797966, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Nieuwlandseweg 46, Amersfoort", "lat": 52.2006142, "lng": 5.3796174, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Nieuwlandseweg 48, Amersfoort", "lat": 52.2007408, "lng": 5.3793392, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Nieuwlandseweg 50, Amersfoort", "lat": 52.2006953, "lng": 5.3790366, "expected_has_charger": None},  # 221m², 1vbo
    {"adres": "Noorderlicht 67, Amersfoort", "lat": 52.1997890, "lng": 5.3775632, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 69, Amersfoort", "lat": 52.1997511, "lng": 5.3776142, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 71, Amersfoort", "lat": 52.1997145, "lng": 5.3776675, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 73, Amersfoort", "lat": 52.1996818, "lng": 5.3777207, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 75, Amersfoort", "lat": 52.1996439, "lng": 5.3777718, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 77, Amersfoort", "lat": 52.1996086, "lng": 5.3778207, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 79, Amersfoort", "lat": 52.1995668, "lng": 5.3778739, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 81, Amersfoort", "lat": 52.1995355, "lng": 5.3779270, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 83, Amersfoort", "lat": 52.1994975, "lng": 5.3779867, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 85, Amersfoort", "lat": 52.1994622, "lng": 5.3780291, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 87, Amersfoort", "lat": 52.1994230, "lng": 5.3780824, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 89, Amersfoort", "lat": 52.1993891, "lng": 5.3781334, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 91, Amersfoort", "lat": 52.1993498, "lng": 5.3781930, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 93, Amersfoort", "lat": 52.1993106, "lng": 5.3782525, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 95, Amersfoort", "lat": 52.1992740, "lng": 5.3783036, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 97, Amersfoort", "lat": 52.1992375, "lng": 5.3783546, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 99, Amersfoort", "lat": 52.1992047, "lng": 5.3784036, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 101, Amersfoort", "lat": 52.1991682, "lng": 5.3784569, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 103, Amersfoort", "lat": 52.1991316, "lng": 5.3785035, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 105, Amersfoort", "lat": 52.1990911, "lng": 5.3785568, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 107, Amersfoort", "lat": 52.1990689, "lng": 5.3786631, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Noorderlicht 109, Amersfoort", "lat": 52.1989918, "lng": 5.3786504, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Noorderlicht 111, Amersfoort", "lat": 52.1989812, "lng": 5.3785483, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 115, Amersfoort", "lat": 52.1989211, "lng": 5.3784249, "expected_has_charger": None},  # 294m², 1vbo
    {"adres": "Noorderlicht 117, Amersfoort", "lat": 52.1988897, "lng": 5.3783676, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 119, Amersfoort", "lat": 52.1988557, "lng": 5.3783016, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 121, Amersfoort", "lat": 52.1988244, "lng": 5.3782526, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 123, Amersfoort", "lat": 52.1987930, "lng": 5.3781888, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 125, Amersfoort", "lat": 52.1987590, "lng": 5.3781271, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 127, Amersfoort", "lat": 52.1987237, "lng": 5.3780633, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 129, Amersfoort", "lat": 52.1986963, "lng": 5.3780059, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 131, Amersfoort", "lat": 52.1986571, "lng": 5.3779485, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 133, Amersfoort", "lat": 52.1986257, "lng": 5.3778953, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 135, Amersfoort", "lat": 52.1985956, "lng": 5.3778380, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Noorderlicht 137, Amersfoort", "lat": 52.1985616, "lng": 5.3777805, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Notarisappelgaarde 1, Amersfoort", "lat": 52.1959663, "lng": 5.3693544, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Notarisappelgaarde 2, Amersfoort", "lat": 52.1952789, "lng": 5.3697070, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Notarisappelgaarde 3, Amersfoort", "lat": 52.1960007, "lng": 5.3694103, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 4, Amersfoort", "lat": 52.1953407, "lng": 5.3697518, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Notarisappelgaarde 5, Amersfoort", "lat": 52.1960351, "lng": 5.3694663, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Notarisappelgaarde 6, Amersfoort", "lat": 52.1953820, "lng": 5.3697910, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Notarisappelgaarde 7, Amersfoort", "lat": 52.1960729, "lng": 5.3695222, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 8, Amersfoort", "lat": 52.1954370, "lng": 5.3698301, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 9, Amersfoort", "lat": 52.1961107, "lng": 5.3695725, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 10, Amersfoort", "lat": 52.1954886, "lng": 5.3698749, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Notarisappelgaarde 11, Amersfoort", "lat": 52.1961416, "lng": 5.3696340, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 12, Amersfoort", "lat": 52.1955367, "lng": 5.3699252, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Notarisappelgaarde 13, Amersfoort", "lat": 52.1961760, "lng": 5.3696843, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 14, Amersfoort", "lat": 52.1955814, "lng": 5.3699643, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Notarisappelgaarde 15, Amersfoort", "lat": 52.1962104, "lng": 5.3697514, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 16, Amersfoort", "lat": 52.1956226, "lng": 5.3700258, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Notarisappelgaarde 17, Amersfoort", "lat": 52.1962448, "lng": 5.3698074, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 18, Amersfoort", "lat": 52.1956776, "lng": 5.3700594, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Notarisappelgaarde 19, Amersfoort", "lat": 52.1962792, "lng": 5.3698577, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Notarisappelgaarde 20, Amersfoort", "lat": 52.1957326, "lng": 5.3701097, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Notarisappelgaarde 21, Amersfoort", "lat": 52.1963170, "lng": 5.3699136, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Notarisappelgaarde 22, Amersfoort", "lat": 52.1957808, "lng": 5.3701488, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Notarisappelgaarde 24, Amersfoort", "lat": 52.1958289, "lng": 5.3701879, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Notarisappelgaarde 26, Amersfoort", "lat": 52.1958805, "lng": 5.3702326, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Notarisappelgaarde 28, Amersfoort", "lat": 52.1959286, "lng": 5.3702831, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Notarisappelgaarde 30, Amersfoort", "lat": 52.1959802, "lng": 5.3703221, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Notarisappelgaarde 32, Amersfoort", "lat": 52.1960215, "lng": 5.3703725, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Notarisappelgaarde 34, Amersfoort", "lat": 52.1962483, "lng": 5.3705346, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Notarisappelgaarde 36, Amersfoort", "lat": 52.1962793, "lng": 5.3704618, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 38, Amersfoort", "lat": 52.1963137, "lng": 5.3704059, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 40, Amersfoort", "lat": 52.1963514, "lng": 5.3703500, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 42, Amersfoort", "lat": 52.1963858, "lng": 5.3702996, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 44, Amersfoort", "lat": 52.1964167, "lng": 5.3702437, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 46, Amersfoort", "lat": 52.1964512, "lng": 5.3701934, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 48, Amersfoort", "lat": 52.1964889, "lng": 5.3701262, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 50, Amersfoort", "lat": 52.1965233, "lng": 5.3700757, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Notarisappelgaarde 52, Amersfoort", "lat": 52.1965542, "lng": 5.3700143, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 1, Amersfoort", "lat": 52.1957301, "lng": 5.3830618, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 3, Amersfoort", "lat": 52.1958568, "lng": 5.3832589, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 5, Amersfoort", "lat": 52.1959747, "lng": 5.3834356, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 7, Amersfoort", "lat": 52.1960675, "lng": 5.3836060, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 9, Amersfoort", "lat": 52.1961667, "lng": 5.3837545, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 11, Amersfoort", "lat": 52.1962488, "lng": 5.3839283, "expected_has_charger": None},  # 256m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 13, Amersfoort", "lat": 52.1963369, "lng": 5.3840891, "expected_has_charger": None},  # 261m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 15, Amersfoort", "lat": 52.1964076, "lng": 5.3842414, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 17, Amersfoort", "lat": 52.1964875, "lng": 5.3844310, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 19A, Amersfoort", "lat": 52.1965901, "lng": 5.3839970, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 19B, Amersfoort", "lat": 52.1966665, "lng": 5.3838799, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 19C, Amersfoort", "lat": 52.1967029, "lng": 5.3843676, "expected_has_charger": None},  # 244m², 1vbo
    {"adres": "Oude Zevenhuizerstraat 19D, Amersfoort", "lat": 52.1965693, "lng": 5.3846456, "expected_has_charger": None},  # 226m², 1vbo
    {"adres": "Parnaskruid 1, Amersfoort", "lat": 52.2027158, "lng": 5.3847014, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 2, Amersfoort", "lat": 52.2029759, "lng": 5.3844910, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Parnaskruid 3, Amersfoort", "lat": 52.2027042, "lng": 5.3845828, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 4, Amersfoort", "lat": 52.2029693, "lng": 5.3844290, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Parnaskruid 5, Amersfoort", "lat": 52.2026894, "lng": 5.3844776, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 6, Amersfoort", "lat": 52.2029643, "lng": 5.3843724, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Parnaskruid 7, Amersfoort", "lat": 52.2026744, "lng": 5.3843724, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 8, Amersfoort", "lat": 52.2029560, "lng": 5.3843049, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Parnaskruid 9, Amersfoort", "lat": 52.2026595, "lng": 5.3842644, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 10, Amersfoort", "lat": 52.2029461, "lng": 5.3842375, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Parnaskruid 11, Amersfoort", "lat": 52.2026462, "lng": 5.3841566, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 12, Amersfoort", "lat": 52.2029378, "lng": 5.3841783, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Parnaskruid 13, Amersfoort", "lat": 52.2026346, "lng": 5.3840543, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 14, Amersfoort", "lat": 52.2029312, "lng": 5.3841054, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Parnaskruid 15, Amersfoort", "lat": 52.2026230, "lng": 5.3839463, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 16, Amersfoort", "lat": 52.2029212, "lng": 5.3840460, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Parnaskruid 17, Amersfoort", "lat": 52.2026081, "lng": 5.3838358, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 18, Amersfoort", "lat": 52.2027754, "lng": 5.3832345, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Parnaskruid 19, Amersfoort", "lat": 52.2025932, "lng": 5.3837333, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 20, Amersfoort", "lat": 52.2027672, "lng": 5.3831536, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Parnaskruid 21, Amersfoort", "lat": 52.2025750, "lng": 5.3836227, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 22, Amersfoort", "lat": 52.2027539, "lng": 5.3830727, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Parnaskruid 23, Amersfoort", "lat": 52.2025634, "lng": 5.3835203, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 24, Amersfoort", "lat": 52.2027456, "lng": 5.3829972, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Parnaskruid 25, Amersfoort", "lat": 52.2025518, "lng": 5.3834097, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 26, Amersfoort", "lat": 52.2027373, "lng": 5.3829163, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Parnaskruid 27, Amersfoort", "lat": 52.2025369, "lng": 5.3833073, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 28, Amersfoort", "lat": 52.2027075, "lng": 5.3826413, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Parnaskruid 29, Amersfoort", "lat": 52.2025203, "lng": 5.3831941, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 30, Amersfoort", "lat": 52.2027506, "lng": 5.3825901, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 31, Amersfoort", "lat": 52.2025087, "lng": 5.3830781, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 32, Amersfoort", "lat": 52.2027854, "lng": 5.3825442, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Parnaskruid 33, Amersfoort", "lat": 52.2024938, "lng": 5.3829784, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 34, Amersfoort", "lat": 52.2028235, "lng": 5.3824903, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 35, Amersfoort", "lat": 52.2024805, "lng": 5.3828651, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 36, Amersfoort", "lat": 52.2028583, "lng": 5.3824337, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 37, Amersfoort", "lat": 52.2024706, "lng": 5.3827573, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Parnaskruid 38, Amersfoort", "lat": 52.2028980, "lng": 5.3823771, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 39, Amersfoort", "lat": 52.2024507, "lng": 5.3826548, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Parnaskruid 40, Amersfoort", "lat": 52.2029312, "lng": 5.3823123, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Parnaskruid 42, Amersfoort", "lat": 52.2030223, "lng": 5.3821667, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Parnaskruid 44, Amersfoort", "lat": 52.2030603, "lng": 5.3821073, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 46, Amersfoort", "lat": 52.2030984, "lng": 5.3820507, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Parnaskruid 48, Amersfoort", "lat": 52.2031316, "lng": 5.3819915, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 50, Amersfoort", "lat": 52.2031647, "lng": 5.3819321, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 52, Amersfoort", "lat": 52.2032011, "lng": 5.3818728, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 54, Amersfoort", "lat": 52.2032326, "lng": 5.3818189, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Parnaskruid 56, Amersfoort", "lat": 52.2032724, "lng": 5.3817594, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 58, Amersfoort", "lat": 52.2033039, "lng": 5.3817002, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 60, Amersfoort", "lat": 52.2033353, "lng": 5.3816355, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Parnaskruid 62, Amersfoort", "lat": 52.2034198, "lng": 5.3814790, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Parnaskruid 64, Amersfoort", "lat": 52.2034513, "lng": 5.3814063, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 66, Amersfoort", "lat": 52.2034828, "lng": 5.3813443, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 68, Amersfoort", "lat": 52.2035160, "lng": 5.3812768, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 70, Amersfoort", "lat": 52.2035474, "lng": 5.3812148, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 72, Amersfoort", "lat": 52.2035789, "lng": 5.3811528, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 74, Amersfoort", "lat": 52.2036103, "lng": 5.3810908, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 76, Amersfoort", "lat": 52.2036352, "lng": 5.3810261, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 78, Amersfoort", "lat": 52.2036667, "lng": 5.3809613, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 80, Amersfoort", "lat": 52.2036965, "lng": 5.3808966, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 82, Amersfoort", "lat": 52.2037213, "lng": 5.3808320, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Parnaskruid 84, Amersfoort", "lat": 52.2037822, "lng": 5.3806804, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Parnaskruid 86, Amersfoort", "lat": 52.2038137, "lng": 5.3806062, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 88, Amersfoort", "lat": 52.2038419, "lng": 5.3805356, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 90, Amersfoort", "lat": 52.2038712, "lng": 5.3804702, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 92, Amersfoort", "lat": 52.2038973, "lng": 5.3804030, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 94, Amersfoort", "lat": 52.2039232, "lng": 5.3803324, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 96, Amersfoort", "lat": 52.2039493, "lng": 5.3802636, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Parnaskruid 98, Amersfoort", "lat": 52.2039743, "lng": 5.3802000, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Parnaskruid 100, Amersfoort", "lat": 52.2039981, "lng": 5.3801293, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Patriciërslaan 1, Amersfoort", "lat": 52.1963701, "lng": 5.3804856, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 2, Amersfoort", "lat": 52.1965524, "lng": 5.3808271, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 3, Amersfoort", "lat": 52.1964018, "lng": 5.3804373, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 4, Amersfoort", "lat": 52.1965842, "lng": 5.3807822, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 5, Amersfoort", "lat": 52.1964294, "lng": 5.3803787, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 6, Amersfoort", "lat": 52.1966265, "lng": 5.3807478, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Patriciërslaan 7, Amersfoort", "lat": 52.1964675, "lng": 5.3803235, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 8, Amersfoort", "lat": 52.1966626, "lng": 5.3806892, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 9, Amersfoort", "lat": 52.1965057, "lng": 5.3802684, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 10, Amersfoort", "lat": 52.1966986, "lng": 5.3806339, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Patriciërslaan 11, Amersfoort", "lat": 52.1965418, "lng": 5.3802166, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 12, Amersfoort", "lat": 52.1967389, "lng": 5.3805822, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 13, Amersfoort", "lat": 52.1965820, "lng": 5.3801544, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Patriciërslaan 14, Amersfoort", "lat": 52.1968187, "lng": 5.3806342, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Patriciërslaan 15, Amersfoort", "lat": 52.1966181, "lng": 5.3801028, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Patriciërslaan 16, Amersfoort", "lat": 52.1968130, "lng": 5.3804753, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Patriciërslaan 17, Amersfoort", "lat": 52.1967537, "lng": 5.3798992, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Patriciërslaan 18, Amersfoort", "lat": 52.1969508, "lng": 5.3802821, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Patriciërslaan 19, Amersfoort", "lat": 52.1967961, "lng": 5.3798509, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Patriciërslaan 20, Amersfoort", "lat": 52.1969932, "lng": 5.3802165, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Patriciërslaan 21, Amersfoort", "lat": 52.1968384, "lng": 5.3797958, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Patriciërslaan 22, Amersfoort", "lat": 52.1970356, "lng": 5.3801648, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 23, Amersfoort", "lat": 52.1968724, "lng": 5.3797440, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Patriciërslaan 24, Amersfoort", "lat": 52.1970674, "lng": 5.3801096, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Patriciërslaan 25, Amersfoort", "lat": 52.1969105, "lng": 5.3796853, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Patriciërslaan 26, Amersfoort", "lat": 52.1971098, "lng": 5.3800474, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Patriciërslaan 27, Amersfoort", "lat": 52.1969508, "lng": 5.3796335, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Patriciërslaan 28, Amersfoort", "lat": 52.1971458, "lng": 5.3799923, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Patriciërslaan 29, Amersfoort", "lat": 52.1969847, "lng": 5.3795784, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Patriciërslaan 30, Amersfoort", "lat": 52.1971861, "lng": 5.3799371, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 31, Amersfoort", "lat": 52.1970271, "lng": 5.3795233, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Patriciërslaan 32, Amersfoort", "lat": 52.1972200, "lng": 5.3798819, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 33, Amersfoort", "lat": 52.1970441, "lng": 5.3794336, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 34, Amersfoort", "lat": 52.1972772, "lng": 5.3798750, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 35, Amersfoort", "lat": 52.1973323, "lng": 5.3790161, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 36, Amersfoort", "lat": 52.1975676, "lng": 5.3794541, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 37, Amersfoort", "lat": 52.1974001, "lng": 5.3789884, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Patriciërslaan 38, Amersfoort", "lat": 52.1975930, "lng": 5.3793403, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 39, Amersfoort", "lat": 52.1974382, "lng": 5.3789368, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Patriciërslaan 40, Amersfoort", "lat": 52.1976354, "lng": 5.3792989, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Patriciërslaan 41, Amersfoort", "lat": 52.1974764, "lng": 5.3788781, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Patriciërslaan 42, Amersfoort", "lat": 52.1976714, "lng": 5.3792438, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Patriciërslaan 43, Amersfoort", "lat": 52.1975145, "lng": 5.3788264, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Patriciërslaan 44, Amersfoort", "lat": 52.1977096, "lng": 5.3791851, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Patriciërslaan 45, Amersfoort", "lat": 52.1975548, "lng": 5.3787712, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Patriciërslaan 46, Amersfoort", "lat": 52.1977477, "lng": 5.3791333, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 47, Amersfoort", "lat": 52.1975930, "lng": 5.3787159, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Patriciërslaan 48, Amersfoort", "lat": 52.1977901, "lng": 5.3790815, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Patriciërslaan 49, Amersfoort", "lat": 52.1976290, "lng": 5.3786608, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 50, Amersfoort", "lat": 52.1978219, "lng": 5.3790264, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Patriciërslaan 51, Amersfoort", "lat": 52.1976693, "lng": 5.3786021, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 52, Amersfoort", "lat": 52.1978622, "lng": 5.3789677, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Patriciërslaan 53, Amersfoort", "lat": 52.1977053, "lng": 5.3785470, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Patriciërslaan 54, Amersfoort", "lat": 52.1979025, "lng": 5.3789195, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Patriciërslaan 55, Amersfoort", "lat": 52.1978325, "lng": 5.3783537, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Patriciërslaan 56, Amersfoort", "lat": 52.1980381, "lng": 5.3787262, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Patriciërslaan 57, Amersfoort", "lat": 52.1978833, "lng": 5.3782951, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 58, Amersfoort", "lat": 52.1980783, "lng": 5.3786607, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 59, Amersfoort", "lat": 52.1979194, "lng": 5.3782434, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Patriciërslaan 60, Amersfoort", "lat": 52.1981165, "lng": 5.3786055, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 61, Amersfoort", "lat": 52.1979597, "lng": 5.3781881, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Patriciërslaan 62, Amersfoort", "lat": 52.1981546, "lng": 5.3785538, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 63, Amersfoort", "lat": 52.1979977, "lng": 5.3781330, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Patriciërslaan 64, Amersfoort", "lat": 52.1981949, "lng": 5.3784951, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 65, Amersfoort", "lat": 52.1980338, "lng": 5.3780812, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Patriciërslaan 66, Amersfoort", "lat": 52.1982331, "lng": 5.3784399, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 67, Amersfoort", "lat": 52.1980762, "lng": 5.3780260, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Patriciërslaan 68, Amersfoort", "lat": 52.1982691, "lng": 5.3783846, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Patriciërslaan 69, Amersfoort", "lat": 52.1981123, "lng": 5.3779743, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 70, Amersfoort", "lat": 52.1982988, "lng": 5.3783261, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Patriciërslaan 71, Amersfoort", "lat": 52.1981419, "lng": 5.3779432, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Patriciërslaan 72, Amersfoort", "lat": 52.1983284, "lng": 5.3782812, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Penningkruid 2, Amersfoort", "lat": 52.2041507, "lng": 5.3802647, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Penningkruid 4, Amersfoort", "lat": 52.2042008, "lng": 5.3802801, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Penningkruid 6, Amersfoort", "lat": 52.2042508, "lng": 5.3803000, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Penningkruid 8, Amersfoort", "lat": 52.2042982, "lng": 5.3803153, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Penningkruid 10, Amersfoort", "lat": 52.2043483, "lng": 5.3803352, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Penningkruid 12, Amersfoort", "lat": 52.2043928, "lng": 5.3803440, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Pijlkruid 1, Amersfoort", "lat": 52.2039716, "lng": 5.3807082, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 2, Amersfoort", "lat": 52.2038410, "lng": 5.3810161, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 3, Amersfoort", "lat": 52.2040219, "lng": 5.3807400, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 4, Amersfoort", "lat": 52.2038893, "lng": 5.3810664, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 5, Amersfoort", "lat": 52.2040682, "lng": 5.3807684, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 6, Amersfoort", "lat": 52.2039356, "lng": 5.3811031, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Pijlkruid 7, Amersfoort", "lat": 52.2041134, "lng": 5.3807952, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 8, Amersfoort", "lat": 52.2039829, "lng": 5.3811283, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 9, Amersfoort", "lat": 52.2041618, "lng": 5.3808237, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Pijlkruid 10, Amersfoort", "lat": 52.2040302, "lng": 5.3811650, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 11, Amersfoort", "lat": 52.2042070, "lng": 5.3808487, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 12, Amersfoort", "lat": 52.2040713, "lng": 5.3812052, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 13, Amersfoort", "lat": 52.2042533, "lng": 5.3808739, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 14, Amersfoort", "lat": 52.2041155, "lng": 5.3812421, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pijlkruid 16, Amersfoort", "lat": 52.2041556, "lng": 5.3812805, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 1, Amersfoort", "lat": 52.2045076, "lng": 5.3763274, "expected_has_charger": None},  # 204m², 1vbo
    {"adres": "Pitrus 2, Amersfoort", "lat": 52.2047409, "lng": 5.3765286, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Pitrus 3, Amersfoort", "lat": 52.2045262, "lng": 5.3762214, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 4, Amersfoort", "lat": 52.2047550, "lng": 5.3764509, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Pitrus 5, Amersfoort", "lat": 52.2045331, "lng": 5.3761284, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 6, Amersfoort", "lat": 52.2047656, "lng": 5.3763762, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Pitrus 7, Amersfoort", "lat": 52.2045504, "lng": 5.3760494, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 8, Amersfoort", "lat": 52.2047780, "lng": 5.3763128, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Pitrus 9, Amersfoort", "lat": 52.2045591, "lng": 5.3759507, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 10, Amersfoort", "lat": 52.2047886, "lng": 5.3762324, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Pitrus 11, Amersfoort", "lat": 52.2045798, "lng": 5.3758520, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 12, Amersfoort", "lat": 52.2047939, "lng": 5.3761662, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Pitrus 13, Amersfoort", "lat": 52.2045919, "lng": 5.3757533, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 14, Amersfoort", "lat": 52.2048098, "lng": 5.3761001, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 15, Amersfoort", "lat": 52.2046076, "lng": 5.3756632, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 16, Amersfoort", "lat": 52.2048185, "lng": 5.3760310, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Pitrus 17, Amersfoort", "lat": 52.2046283, "lng": 5.3755729, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Pitrus 18, Amersfoort", "lat": 52.2048327, "lng": 5.3759418, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Pitrus 19, Amersfoort", "lat": 52.2049141, "lng": 5.3753304, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 20, Amersfoort", "lat": 52.2048415, "lng": 5.3758757, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Pitrus 21, Amersfoort", "lat": 52.2049764, "lng": 5.3753755, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 22, Amersfoort", "lat": 52.2048539, "lng": 5.3757952, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Pitrus 23, Amersfoort", "lat": 52.2050405, "lng": 5.3754150, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 24, Amersfoort", "lat": 52.2048609, "lng": 5.3757376, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 25, Amersfoort", "lat": 52.2051116, "lng": 5.3754515, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 26, Amersfoort", "lat": 52.2048698, "lng": 5.3756685, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Pitrus 27, Amersfoort", "lat": 52.2051705, "lng": 5.3754770, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 28, Amersfoort", "lat": 52.2055723, "lng": 5.3759561, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Pitrus 29, Amersfoort", "lat": 52.2052328, "lng": 5.3754825, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 30, Amersfoort", "lat": 52.2055585, "lng": 5.3760154, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Pitrus 31, Amersfoort", "lat": 52.2053887, "lng": 5.3755220, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 32, Amersfoort", "lat": 52.2055481, "lng": 5.3760971, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 33, Amersfoort", "lat": 52.2054614, "lng": 5.3755332, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 34, Amersfoort", "lat": 52.2055377, "lng": 5.3761732, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 35, Amersfoort", "lat": 52.2055255, "lng": 5.3755474, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 36, Amersfoort", "lat": 52.2055291, "lng": 5.3762408, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 37, Amersfoort", "lat": 52.2055931, "lng": 5.3755699, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 38, Amersfoort", "lat": 52.2055135, "lng": 5.3763058, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 39, Amersfoort", "lat": 52.2056538, "lng": 5.3755699, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Pitrus 40, Amersfoort", "lat": 52.2055065, "lng": 5.3763846, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 41, Amersfoort", "lat": 52.2057248, "lng": 5.3755557, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Pitrus 42, Amersfoort", "lat": 52.2054927, "lng": 5.3764579, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 43, Amersfoort", "lat": 52.2058341, "lng": 5.3755182, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Pitrus 44, Amersfoort", "lat": 52.2054754, "lng": 5.3765256, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Pitrus 45, Amersfoort", "lat": 52.2058747, "lng": 5.3755811, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Pitrus 46, Amersfoort", "lat": 52.2054736, "lng": 5.3766017, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Pitrus 47, Amersfoort", "lat": 52.2059240, "lng": 5.3756529, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Pitrus 48, Amersfoort", "lat": 52.2054615, "lng": 5.3766778, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Pitrus 49, Amersfoort", "lat": 52.2059351, "lng": 5.3757230, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Pitrus 50, Amersfoort", "lat": 52.2054460, "lng": 5.3767512, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Pitrus 51, Amersfoort", "lat": 52.2059392, "lng": 5.3758096, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Pitrus 52, Amersfoort", "lat": 52.2054373, "lng": 5.3768188, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Pitrus 53, Amersfoort", "lat": 52.2059353, "lng": 5.3758785, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Pitrus 55, Amersfoort", "lat": 52.2058113, "lng": 5.3761083, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Pitrus 57, Amersfoort", "lat": 52.2057992, "lng": 5.3762127, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Pitrus 59, Amersfoort", "lat": 52.2057751, "lng": 5.3763254, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Pitrus 61, Amersfoort", "lat": 52.2057525, "lng": 5.3764608, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Pitrus 63, Amersfoort", "lat": 52.2057352, "lng": 5.3765791, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Pitrus 65, Amersfoort", "lat": 52.2057161, "lng": 5.3767172, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Pitrus 67, Amersfoort", "lat": 52.2056937, "lng": 5.3768328, "expected_has_charger": None},  # 202m², 1vbo
    {"adres": "Pondspeergaarde 1, Amersfoort", "lat": 52.1975077, "lng": 5.3728142, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Pondspeergaarde 2, Amersfoort", "lat": 52.1976666, "lng": 5.3730383, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Pondspeergaarde 3, Amersfoort", "lat": 52.1976009, "lng": 5.3726797, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Pondspeergaarde 4, Amersfoort", "lat": 52.1977048, "lng": 5.3729763, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Pondspeergaarde 5, Amersfoort", "lat": 52.1982219, "lng": 5.3721483, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Pondspeergaarde 6, Amersfoort", "lat": 52.1977429, "lng": 5.3729245, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Pondspeergaarde 8, Amersfoort", "lat": 52.1977831, "lng": 5.3728659, "expected_has_charger": None},  # 131m², 1vbo
    {"adres": "Pondspeergaarde 10, Amersfoort", "lat": 52.1978298, "lng": 5.3728107, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Pondspeergaarde 12, Amersfoort", "lat": 52.1978764, "lng": 5.3727693, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Pondspeergaarde 14, Amersfoort", "lat": 52.1979209, "lng": 5.3727312, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Pondspeergaarde 16, Amersfoort", "lat": 52.1979676, "lng": 5.3726898, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Pondspeergaarde 18, Amersfoort", "lat": 52.1980078, "lng": 5.3726588, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Pondspeergaarde 20, Amersfoort", "lat": 52.1980523, "lng": 5.3726140, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Pondspeergaarde 22, Amersfoort", "lat": 52.1980969, "lng": 5.3725726, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Pondspeergaarde 24, Amersfoort", "lat": 52.1981445, "lng": 5.3725312, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Pondspeergaarde 26, Amersfoort", "lat": 52.1981933, "lng": 5.3724932, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Pondspeergaarde 28, Amersfoort", "lat": 52.1982399, "lng": 5.3724621, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Pondspeergaarde 30, Amersfoort", "lat": 52.1982887, "lng": 5.3724449, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Poortersdreef 1, Amersfoort", "lat": 52.1956800, "lng": 5.3769710, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Poortersdreef 2, Amersfoort", "lat": 52.1953810, "lng": 5.3768849, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Poortersdreef 3, Amersfoort", "lat": 52.1956778, "lng": 5.3771400, "expected_has_charger": None},  # 204m², 1vbo
    {"adres": "Poortersdreef 4, Amersfoort", "lat": 52.1953810, "lng": 5.3769745, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 5, Amersfoort", "lat": 52.1956800, "lng": 5.3772263, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Poortersdreef 6, Amersfoort", "lat": 52.1953810, "lng": 5.3771470, "expected_has_charger": None},  # 215m², 1vbo
    {"adres": "Poortersdreef 7, Amersfoort", "lat": 52.1956778, "lng": 5.3774021, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 8, Amersfoort", "lat": 52.1953811, "lng": 5.3772402, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Poortersdreef 9, Amersfoort", "lat": 52.1956800, "lng": 5.3774988, "expected_has_charger": None},  # 199m², 1vbo
    {"adres": "Poortersdreef 10, Amersfoort", "lat": 52.1953811, "lng": 5.3774126, "expected_has_charger": None},  # 199m², 1vbo
    {"adres": "Poortersdreef 11, Amersfoort", "lat": 52.1956800, "lng": 5.3776713, "expected_has_charger": None},  # 209m², 1vbo
    {"adres": "Poortersdreef 12, Amersfoort", "lat": 52.1953811, "lng": 5.3774954, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Poortersdreef 13, Amersfoort", "lat": 52.1956800, "lng": 5.3777574, "expected_has_charger": None},  # 204m², 1vbo
    {"adres": "Poortersdreef 14, Amersfoort", "lat": 52.1953790, "lng": 5.3776713, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Poortersdreef 15, Amersfoort", "lat": 52.1956800, "lng": 5.3779437, "expected_has_charger": None},  # 201m², 1vbo
    {"adres": "Poortersdreef 16, Amersfoort", "lat": 52.1953811, "lng": 5.3777645, "expected_has_charger": None},  # 213m², 1vbo
    {"adres": "Poortersdreef 17, Amersfoort", "lat": 52.1956821, "lng": 5.3780196, "expected_has_charger": None},  # 196m², 1vbo
    {"adres": "Poortersdreef 18, Amersfoort", "lat": 52.1953790, "lng": 5.3779369, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Poortersdreef 19, Amersfoort", "lat": 52.1956821, "lng": 5.3781954, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Poortersdreef 20, Amersfoort", "lat": 52.1953727, "lng": 5.3780231, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 21, Amersfoort", "lat": 52.1956821, "lng": 5.3782853, "expected_has_charger": None},  # 196m², 1vbo
    {"adres": "Poortersdreef 22, Amersfoort", "lat": 52.1953811, "lng": 5.3782232, "expected_has_charger": None},  # 203m², 1vbo
    {"adres": "Poortersdreef 23, Amersfoort", "lat": 52.1956821, "lng": 5.3784577, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Poortersdreef 24, Amersfoort", "lat": 52.1953875, "lng": 5.3783197, "expected_has_charger": None},  # 211m², 1vbo
    {"adres": "Poortersdreef 25, Amersfoort", "lat": 52.1956822, "lng": 5.3785507, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 26, Amersfoort", "lat": 52.1953811, "lng": 5.3784852, "expected_has_charger": None},  # 199m², 1vbo
    {"adres": "Poortersdreef 27, Amersfoort", "lat": 52.1956822, "lng": 5.3787233, "expected_has_charger": None},  # 196m², 1vbo
    {"adres": "Poortersdreef 28, Amersfoort", "lat": 52.1953812, "lng": 5.3785749, "expected_has_charger": None},  # 213m², 1vbo
    {"adres": "Poortersdreef 29, Amersfoort", "lat": 52.1956822, "lng": 5.3788061, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 30, Amersfoort", "lat": 52.1953812, "lng": 5.3787475, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 31, Amersfoort", "lat": 52.1956843, "lng": 5.3789819, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Poortersdreef 32, Amersfoort", "lat": 52.1953812, "lng": 5.3788440, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Poortersdreef 33, Amersfoort", "lat": 52.1956844, "lng": 5.3790786, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Poortersdreef 34, Amersfoort", "lat": 52.1953833, "lng": 5.3790129, "expected_has_charger": None},  # 188m², 1vbo
    {"adres": "Poortersdreef 35, Amersfoort", "lat": 52.1956886, "lng": 5.3792716, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 36, Amersfoort", "lat": 52.1953855, "lng": 5.3791027, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Poortersdreef 37, Amersfoort", "lat": 52.1957225, "lng": 5.3793820, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Poortersdreef 38, Amersfoort", "lat": 52.1953834, "lng": 5.3792752, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Poortersdreef 39, Amersfoort", "lat": 52.1957967, "lng": 5.3795268, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Poortersdreef 40, Amersfoort", "lat": 52.1953834, "lng": 5.3793648, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Poortersdreef 41, Amersfoort", "lat": 52.1958348, "lng": 5.3795959, "expected_has_charger": None},  # 207m², 1vbo
    {"adres": "Poortersdreef 42, Amersfoort", "lat": 52.1954978, "lng": 5.3797511, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Poortersdreef 43, Amersfoort", "lat": 52.1959005, "lng": 5.3797304, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 44, Amersfoort", "lat": 52.1955318, "lng": 5.3798235, "expected_has_charger": None},  # 193m², 1vbo
    {"adres": "Poortersdreef 45, Amersfoort", "lat": 52.1959388, "lng": 5.3797959, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 46, Amersfoort", "lat": 52.1956017, "lng": 5.3799408, "expected_has_charger": None},  # 211m², 1vbo
    {"adres": "Poortersdreef 47, Amersfoort", "lat": 52.1960065, "lng": 5.3799338, "expected_has_charger": None},  # 196m², 1vbo
    {"adres": "Poortersdreef 48, Amersfoort", "lat": 52.1956398, "lng": 5.3800098, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Poortersdreef 49, Amersfoort", "lat": 52.1960426, "lng": 5.3799960, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Poortersdreef 50, Amersfoort", "lat": 52.1957205, "lng": 5.3801304, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Poortersdreef 51, Amersfoort", "lat": 52.1961147, "lng": 5.3801235, "expected_has_charger": None},  # 196m², 1vbo
    {"adres": "Poortersdreef 52, Amersfoort", "lat": 52.1957543, "lng": 5.3801960, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Poortersdreef 53, Amersfoort", "lat": 52.1961507, "lng": 5.3801994, "expected_has_charger": None},  # 204m², 1vbo
    {"adres": "Poortersdreef 54, Amersfoort", "lat": 52.1958264, "lng": 5.3803271, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Poortersdreef 55, Amersfoort", "lat": 52.1963139, "lng": 5.3804925, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Poortersdreef 56, Amersfoort", "lat": 52.1958582, "lng": 5.3803995, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Poortersdreef 57, Amersfoort", "lat": 52.1965556, "lng": 5.3809340, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Poortersdreef 58, Amersfoort", "lat": 52.1959260, "lng": 5.3805306, "expected_has_charger": None},  # 199m², 1vbo
    {"adres": "Poortersdreef 59, Amersfoort", "lat": 52.1966912, "lng": 5.3812134, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Poortersdreef 60, Amersfoort", "lat": 52.1959621, "lng": 5.3805961, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Poortersdreef 61, Amersfoort", "lat": 52.1967378, "lng": 5.3812893, "expected_has_charger": None},  # 206m², 1vbo
    {"adres": "Poortersdreef 62, Amersfoort", "lat": 52.1960935, "lng": 5.3808686, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Poortersdreef 63, Amersfoort", "lat": 52.1968015, "lng": 5.3814134, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 64, Amersfoort", "lat": 52.1962758, "lng": 5.3812273, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Poortersdreef 65, Amersfoort", "lat": 52.1968418, "lng": 5.3814858, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Poortersdreef 66, Amersfoort", "lat": 52.1964538, "lng": 5.3814894, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Poortersdreef 67, Amersfoort", "lat": 52.1969075, "lng": 5.3816135, "expected_has_charger": None},  # 196m², 1vbo
    {"adres": "Poortersdreef 68, Amersfoort", "lat": 52.1964899, "lng": 5.3815653, "expected_has_charger": None},  # 203m², 1vbo
    {"adres": "Poortersdreef 69, Amersfoort", "lat": 52.1969456, "lng": 5.3816825, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Poortersdreef 70, Amersfoort", "lat": 52.1965577, "lng": 5.3816895, "expected_has_charger": None},  # 207m², 1vbo
    {"adres": "Poortersdreef 71, Amersfoort", "lat": 52.1970177, "lng": 5.3818101, "expected_has_charger": None},  # 207m², 1vbo
    {"adres": "Poortersdreef 72, Amersfoort", "lat": 52.1965938, "lng": 5.3817583, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Poortersdreef 73, Amersfoort", "lat": 52.1970537, "lng": 5.3818756, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Poortersdreef 74, Amersfoort", "lat": 52.1966637, "lng": 5.3818929, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Poortersdreef 75, Amersfoort", "lat": 52.1971385, "lng": 5.3820239, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Poortersdreef 76, Amersfoort", "lat": 52.1967040, "lng": 5.3819584, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Poortersdreef 77, Amersfoort", "lat": 52.1971999, "lng": 5.3820721, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 78, Amersfoort", "lat": 52.1967719, "lng": 5.3820895, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 79, Amersfoort", "lat": 52.1973271, "lng": 5.3821067, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Poortersdreef 80, Amersfoort", "lat": 52.1968058, "lng": 5.3821550, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Poortersdreef 81, Amersfoort", "lat": 52.1973780, "lng": 5.3821239, "expected_has_charger": None},  # 206m², 1vbo
    {"adres": "Poortersdreef 82, Amersfoort", "lat": 52.1968778, "lng": 5.3822999, "expected_has_charger": None},  # 196m², 1vbo
    {"adres": "Poortersdreef 83, Amersfoort", "lat": 52.1974883, "lng": 5.3821376, "expected_has_charger": None},  # 207m², 1vbo
    {"adres": "Poortersdreef 84, Amersfoort", "lat": 52.1969097, "lng": 5.3823517, "expected_has_charger": None},  # 183m², 1vbo
    {"adres": "Poortersdreef 85, Amersfoort", "lat": 52.1975434, "lng": 5.3821549, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Poortersdreef 86, Amersfoort", "lat": 52.1969817, "lng": 5.3825069, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 87, Amersfoort", "lat": 52.1976409, "lng": 5.3821790, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Poortersdreef 88, Amersfoort", "lat": 52.1970474, "lng": 5.3825620, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 89, Amersfoort", "lat": 52.1976981, "lng": 5.3821929, "expected_has_charger": None},  # 211m², 1vbo
    {"adres": "Poortersdreef 90, Amersfoort", "lat": 52.1971533, "lng": 5.3825896, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 91, Amersfoort", "lat": 52.1978062, "lng": 5.3822170, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Poortersdreef 92, Amersfoort", "lat": 52.1972127, "lng": 5.3825965, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 93, Amersfoort", "lat": 52.1978592, "lng": 5.3822239, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Poortersdreef 94, Amersfoort", "lat": 52.1973209, "lng": 5.3826034, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Poortersdreef 95, Amersfoort", "lat": 52.1979652, "lng": 5.3822480, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Poortersdreef 96, Amersfoort", "lat": 52.1973760, "lng": 5.3826241, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 97, Amersfoort", "lat": 52.1980181, "lng": 5.3822584, "expected_has_charger": None},  # 206m², 1vbo
    {"adres": "Poortersdreef 98, Amersfoort", "lat": 52.1974734, "lng": 5.3826483, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Poortersdreef 99, Amersfoort", "lat": 52.1981241, "lng": 5.3822757, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 100, Amersfoort", "lat": 52.1975306, "lng": 5.3826551, "expected_has_charger": None},  # 214m², 1vbo
    {"adres": "Poortersdreef 101, Amersfoort", "lat": 52.1981874, "lng": 5.3822873, "expected_has_charger": None},  # 105m², 2vbo
    {"adres": "Poortersdreef 101A, Amersfoort", "lat": 52.1981905, "lng": 5.3822570, "expected_has_charger": None},  # 111m², 2vbo
    {"adres": "Poortersdreef 102, Amersfoort", "lat": 52.1976366, "lng": 5.3826828, "expected_has_charger": None},  # 206m², 1vbo
    {"adres": "Poortersdreef 103, Amersfoort", "lat": 52.1982866, "lng": 5.3823126, "expected_has_charger": None},  # 202m², 1vbo
    {"adres": "Poortersdreef 104, Amersfoort", "lat": 52.1976986, "lng": 5.3826955, "expected_has_charger": None},  # 211m², 1vbo
    {"adres": "Poortersdreef 105, Amersfoort", "lat": 52.1983369, "lng": 5.3823236, "expected_has_charger": None},  # 201m², 1vbo
    {"adres": "Poortersdreef 106, Amersfoort", "lat": 52.1978027, "lng": 5.3827173, "expected_has_charger": None},  # 207m², 1vbo
    {"adres": "Poortersdreef 107, Amersfoort", "lat": 52.1984512, "lng": 5.3823454, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Poortersdreef 108, Amersfoort", "lat": 52.1978565, "lng": 5.3827338, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 109, Amersfoort", "lat": 52.1985050, "lng": 5.3823618, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Poortersdreef 110, Amersfoort", "lat": 52.1979606, "lng": 5.3827502, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Poortersdreef 111, Amersfoort", "lat": 52.1986091, "lng": 5.3823837, "expected_has_charger": None},  # 197m², 1vbo
    {"adres": "Poortersdreef 112, Amersfoort", "lat": 52.1980178, "lng": 5.3827665, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Poortersdreef 113, Amersfoort", "lat": 52.1986629, "lng": 5.3823947, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Poortersdreef 114, Amersfoort", "lat": 52.1982496, "lng": 5.3828103, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Poortersdreef 115, Amersfoort", "lat": 52.1988779, "lng": 5.3829741, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Poortersdreef 116, Amersfoort", "lat": 52.1983101, "lng": 5.3828212, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Poortersdreef 117, Amersfoort", "lat": 52.1988746, "lng": 5.3830562, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Poortersdreef 118, Amersfoort", "lat": 52.1983874, "lng": 5.3828594, "expected_has_charger": None},  # 235m², 1vbo
    {"adres": "Poortersdreef 119, Amersfoort", "lat": 52.1988679, "lng": 5.3831273, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Poortersdreef 120, Amersfoort", "lat": 52.1985050, "lng": 5.3831109, "expected_has_charger": None},  # 232m², 1vbo
    {"adres": "Poortersdreef 121, Amersfoort", "lat": 52.1988578, "lng": 5.3832148, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "Poortersdreef 122, Amersfoort", "lat": 52.1985151, "lng": 5.3832585, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Poortersdreef 123, Amersfoort", "lat": 52.1988511, "lng": 5.3832859, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "Poortersdreef 124, Amersfoort", "lat": 52.1985084, "lng": 5.3833460, "expected_has_charger": None},  # 213m², 1vbo
    {"adres": "Poortersdreef 125, Amersfoort", "lat": 52.1988477, "lng": 5.3833733, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Poortersdreef 126, Amersfoort", "lat": 52.1984916, "lng": 5.3835211, "expected_has_charger": None},  # 203m², 1vbo
    {"adres": "Poortersdreef 127, Amersfoort", "lat": 52.1988410, "lng": 5.3834554, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Poortersdreef 128, Amersfoort", "lat": 52.1984848, "lng": 5.3836030, "expected_has_charger": None},  # 203m², 1vbo
    {"adres": "Poortersdreef 129, Amersfoort", "lat": 52.1988343, "lng": 5.3835265, "expected_has_charger": None},  # 85m², 1vbo
    {"adres": "Poortersdreef 130, Amersfoort", "lat": 52.1984647, "lng": 5.3837835, "expected_has_charger": None},  # 208m², 1vbo
    {"adres": "Poortersdreef 131, Amersfoort", "lat": 52.1988275, "lng": 5.3835976, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Poortersdreef 132, Amersfoort", "lat": 52.1984546, "lng": 5.3838765, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Poortersdreef 133, Amersfoort", "lat": 52.1988242, "lng": 5.3836796, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Poortersdreef 134, Amersfoort", "lat": 52.1984311, "lng": 5.3840351, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Poortersdreef 136, Amersfoort", "lat": 52.1983303, "lng": 5.3841772, "expected_has_charger": None},  # 210m², 1vbo
    {"adres": "Posthoornslak 2, Amersfoort", "lat": 52.2025612, "lng": 5.3698170, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 4, Amersfoort", "lat": 52.2025508, "lng": 5.3698790, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 6, Amersfoort", "lat": 52.2025370, "lng": 5.3699551, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 8, Amersfoort", "lat": 52.2025318, "lng": 5.3702737, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 10, Amersfoort", "lat": 52.2025327, "lng": 5.3703470, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 12, Amersfoort", "lat": 52.2025344, "lng": 5.3704175, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 14, Amersfoort", "lat": 52.2025363, "lng": 5.3704878, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 16, Amersfoort", "lat": 52.2025397, "lng": 5.3705556, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 18, Amersfoort", "lat": 52.2025466, "lng": 5.3706344, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 20, Amersfoort", "lat": 52.2026038, "lng": 5.3709333, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 22, Amersfoort", "lat": 52.2026177, "lng": 5.3709953, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 24, Amersfoort", "lat": 52.2026333, "lng": 5.3710715, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 26, Amersfoort", "lat": 52.2026558, "lng": 5.3711391, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 28, Amersfoort", "lat": 52.2026714, "lng": 5.3712068, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Posthoornslak 30, Amersfoort", "lat": 52.2026939, "lng": 5.3712659, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Rabouwgaarde 2, Amersfoort", "lat": 52.1958858, "lng": 5.3689458, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Rabouwgaarde 4, Amersfoort", "lat": 52.1958534, "lng": 5.3689931, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 6, Amersfoort", "lat": 52.1958123, "lng": 5.3690683, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 8, Amersfoort", "lat": 52.1957798, "lng": 5.3691268, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 10, Amersfoort", "lat": 52.1957302, "lng": 5.3692048, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 12, Amersfoort", "lat": 52.1957012, "lng": 5.3692576, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 14, Amersfoort", "lat": 52.1956464, "lng": 5.3693439, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 16, Amersfoort", "lat": 52.1956105, "lng": 5.3693941, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 18, Amersfoort", "lat": 52.1955661, "lng": 5.3694719, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Rabouwgaarde 20, Amersfoort", "lat": 52.1955319, "lng": 5.3695165, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Regenboog 36, Amersfoort", "lat": 52.1987587, "lng": 5.3755977, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Regenboog 38, Amersfoort", "lat": 52.1987222, "lng": 5.3756429, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 40, Amersfoort", "lat": 52.1986875, "lng": 5.3756910, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 42, Amersfoort", "lat": 52.1986528, "lng": 5.3757503, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 44, Amersfoort", "lat": 52.1986302, "lng": 5.3758097, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 46, Amersfoort", "lat": 52.1986007, "lng": 5.3758691, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 48, Amersfoort", "lat": 52.1985782, "lng": 5.3759482, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 50, Amersfoort", "lat": 52.1985591, "lng": 5.3760159, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 52, Amersfoort", "lat": 52.1985400, "lng": 5.3760893, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 54, Amersfoort", "lat": 52.1985192, "lng": 5.3761600, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 56, Amersfoort", "lat": 52.1985069, "lng": 5.3762307, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 58, Amersfoort", "lat": 52.1984983, "lng": 5.3763127, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 60, Amersfoort", "lat": 52.1985000, "lng": 5.3765274, "expected_has_charger": None},  # 133m², 1vbo
    {"adres": "Regenboog 62, Amersfoort", "lat": 52.1985053, "lng": 5.3766066, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 64, Amersfoort", "lat": 52.1985140, "lng": 5.3766857, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Regenboog 66, Amersfoort", "lat": 52.1985226, "lng": 5.3767563, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Regenboog 68, Amersfoort", "lat": 52.1985366, "lng": 5.3768325, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Regenboog 70, Amersfoort", "lat": 52.1985522, "lng": 5.3768976, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Regenboog 72, Amersfoort", "lat": 52.1985765, "lng": 5.3769738, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 76, Amersfoort", "lat": 52.1986268, "lng": 5.3771039, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 78, Amersfoort", "lat": 52.1986529, "lng": 5.3771603, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 80, Amersfoort", "lat": 52.1986859, "lng": 5.3772225, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 82, Amersfoort", "lat": 52.1987207, "lng": 5.3772791, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Regenboog 84, Amersfoort", "lat": 52.1988301, "lng": 5.3773977, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Regenboog 86, Amersfoort", "lat": 52.1988735, "lng": 5.3774344, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Regenboog 88, Amersfoort", "lat": 52.1989169, "lng": 5.3774655, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 90, Amersfoort", "lat": 52.1989672, "lng": 5.3774880, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 92, Amersfoort", "lat": 52.1990123, "lng": 5.3775078, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Regenboog 94, Amersfoort", "lat": 52.1990541, "lng": 5.3775247, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Regenboog 96, Amersfoort", "lat": 52.1990992, "lng": 5.3775332, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 98, Amersfoort", "lat": 52.1991461, "lng": 5.3775361, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 100, Amersfoort", "lat": 52.1991895, "lng": 5.3775361, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 102, Amersfoort", "lat": 52.1992381, "lng": 5.3775332, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Regenboog 104, Amersfoort", "lat": 52.1992849, "lng": 5.3775276, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Regenboog 106, Amersfoort", "lat": 52.1993284, "lng": 5.3775134, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 108, Amersfoort", "lat": 52.1993753, "lng": 5.3774936, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Regenboog 110, Amersfoort", "lat": 52.1994204, "lng": 5.3774682, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 112, Amersfoort", "lat": 52.1994621, "lng": 5.3774342, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Regenboog 114, Amersfoort", "lat": 52.1995037, "lng": 5.3774003, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 116, Amersfoort", "lat": 52.1995437, "lng": 5.3773579, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 118, Amersfoort", "lat": 52.1995819, "lng": 5.3773071, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Regenboog 120, Amersfoort", "lat": 52.1996166, "lng": 5.3772619, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Ribbensalamander 2, Amersfoort", "lat": 52.1996884, "lng": 5.3676937, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Ribbensalamander 4, Amersfoort", "lat": 52.1996554, "lng": 5.3677933, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ribbensalamander 6, Amersfoort", "lat": 52.1996261, "lng": 5.3679437, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ribbensalamander 8, Amersfoort", "lat": 52.1996092, "lng": 5.3680608, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ribbensalamander 10, Amersfoort", "lat": 52.1996084, "lng": 5.3681972, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ribbensalamander 12, Amersfoort", "lat": 52.1996193, "lng": 5.3682949, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Ringslang 1, Amersfoort", "lat": 52.2006716, "lng": 5.3736419, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Ringslang 3, Amersfoort", "lat": 52.2007179, "lng": 5.3736460, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 5, Amersfoort", "lat": 52.2007669, "lng": 5.3736501, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 7, Amersfoort", "lat": 52.2008235, "lng": 5.3736501, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 9, Amersfoort", "lat": 52.2009000, "lng": 5.3732763, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 11, Amersfoort", "lat": 52.2008446, "lng": 5.3732578, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 12, Amersfoort", "lat": 52.2010740, "lng": 5.3737710, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Ringslang 13, Amersfoort", "lat": 52.2007957, "lng": 5.3732496, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 14, Amersfoort", "lat": 52.2010858, "lng": 5.3736627, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ringslang 15, Amersfoort", "lat": 52.2007521, "lng": 5.3732498, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 16, Amersfoort", "lat": 52.2011397, "lng": 5.3734418, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Ringslang 17, Amersfoort", "lat": 52.2007030, "lng": 5.3732489, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 18, Amersfoort", "lat": 52.2011805, "lng": 5.3733687, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ringslang 19, Amersfoort", "lat": 52.2007049, "lng": 5.3729511, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Ringslang 20, Amersfoort", "lat": 52.2012646, "lng": 5.3731367, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Ringslang 21, Amersfoort", "lat": 52.2007488, "lng": 5.3729470, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 22, Amersfoort", "lat": 52.2012953, "lng": 5.3730313, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ringslang 23, Amersfoort", "lat": 52.2007951, "lng": 5.3729470, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 24, Amersfoort", "lat": 52.2012583, "lng": 5.3727495, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Ringslang 25, Amersfoort", "lat": 52.2008504, "lng": 5.3729433, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 26, Amersfoort", "lat": 52.2012352, "lng": 5.3726744, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ringslang 27, Amersfoort", "lat": 52.2009024, "lng": 5.3729411, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 28, Amersfoort", "lat": 52.2011527, "lng": 5.3724397, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Ringslang 29, Amersfoort", "lat": 52.2008722, "lng": 5.3725047, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 30, Amersfoort", "lat": 52.2011343, "lng": 5.3723516, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ringslang 31, Amersfoort", "lat": 52.2008207, "lng": 5.3725219, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 32, Amersfoort", "lat": 52.2010795, "lng": 5.3721201, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Ringslang 33, Amersfoort", "lat": 52.2007718, "lng": 5.3725365, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 34, Amersfoort", "lat": 52.2010614, "lng": 5.3720119, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ringslang 35, Amersfoort", "lat": 52.2007243, "lng": 5.3725424, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 36, Amersfoort", "lat": 52.2009931, "lng": 5.3717659, "expected_has_charger": None},  # 195m², 1vbo
    {"adres": "Ringslang 37, Amersfoort", "lat": 52.2006792, "lng": 5.3725594, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 38, Amersfoort", "lat": 52.2009806, "lng": 5.3716523, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Ringslang 39, Amersfoort", "lat": 52.2006522, "lng": 5.3722659, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 41, Amersfoort", "lat": 52.2006939, "lng": 5.3722526, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 43, Amersfoort", "lat": 52.2007385, "lng": 5.3722339, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 45, Amersfoort", "lat": 52.2007911, "lng": 5.3722028, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Ringslang 47, Amersfoort", "lat": 52.2008352, "lng": 5.3721892, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Robertskruid 1, Amersfoort", "lat": 52.2036267, "lng": 5.3815536, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 2, Amersfoort", "lat": 52.2034140, "lng": 5.3819559, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Robertskruid 3, Amersfoort", "lat": 52.2036771, "lng": 5.3815937, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 4, Amersfoort", "lat": 52.2034472, "lng": 5.3820239, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 5, Amersfoort", "lat": 52.2037213, "lng": 5.3816296, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Robertskruid 6, Amersfoort", "lat": 52.2034730, "lng": 5.3820880, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Robertskruid 7, Amersfoort", "lat": 52.2037657, "lng": 5.3816718, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Robertskruid 8, Amersfoort", "lat": 52.2035062, "lng": 5.3821541, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Robertskruid 9, Amersfoort", "lat": 52.2038111, "lng": 5.3817098, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 10, Amersfoort", "lat": 52.2035369, "lng": 5.3822240, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Robertskruid 11, Amersfoort", "lat": 52.2038566, "lng": 5.3817518, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Robertskruid 12, Amersfoort", "lat": 52.2035652, "lng": 5.3822941, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 13, Amersfoort", "lat": 52.2038997, "lng": 5.3817917, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 14, Amersfoort", "lat": 52.2036034, "lng": 5.3823621, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 15, Amersfoort", "lat": 52.2039415, "lng": 5.3818218, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Robertskruid 16, Amersfoort", "lat": 52.2036304, "lng": 5.3824181, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Schone van Boskoopgaarde 1, Amersfoort", "lat": 52.1965205, "lng": 5.3695606, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Schone van Boskoopgaarde 2, Amersfoort", "lat": 52.1965870, "lng": 5.3689176, "expected_has_charger": None},  # 169m², 1vbo
    {"adres": "Schone van Boskoopgaarde 3, Amersfoort", "lat": 52.1964742, "lng": 5.3694800, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 4, Amersfoort", "lat": 52.1964297, "lng": 5.3687869, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Schone van Boskoopgaarde 5, Amersfoort", "lat": 52.1964264, "lng": 5.3693938, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 6, Amersfoort", "lat": 52.1963493, "lng": 5.3686562, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Schone van Boskoopgaarde 7, Amersfoort", "lat": 52.1963768, "lng": 5.3693214, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 8, Amersfoort", "lat": 52.1962706, "lng": 5.3685086, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Schone van Boskoopgaarde 9, Amersfoort", "lat": 52.1963289, "lng": 5.3692434, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Schone van Boskoopgaarde 10, Amersfoort", "lat": 52.1962056, "lng": 5.3683583, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Schone van Boskoopgaarde 11, Amersfoort", "lat": 52.1962810, "lng": 5.3691655, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 12, Amersfoort", "lat": 52.1961406, "lng": 5.3681746, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Schone van Boskoopgaarde 13, Amersfoort", "lat": 52.1962365, "lng": 5.3690875, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 14, Amersfoort", "lat": 52.1960927, "lng": 5.3680133, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Schone van Boskoopgaarde 15, Amersfoort", "lat": 52.1961783, "lng": 5.3689929, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Schone van Boskoopgaarde 16, Amersfoort", "lat": 52.1960755, "lng": 5.3678185, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Schone van Boskoopgaarde 17, Amersfoort", "lat": 52.1960449, "lng": 5.3687648, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Schone van Boskoopgaarde 19, Amersfoort", "lat": 52.1959935, "lng": 5.3687036, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 21, Amersfoort", "lat": 52.1959456, "lng": 5.3686145, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 23, Amersfoort", "lat": 52.1958943, "lng": 5.3685421, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 25, Amersfoort", "lat": 52.1958429, "lng": 5.3684531, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 27, Amersfoort", "lat": 52.1957985, "lng": 5.3683753, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 29, Amersfoort", "lat": 52.1957506, "lng": 5.3683029, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 31, Amersfoort", "lat": 52.1955933, "lng": 5.3684700, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Schone van Boskoopgaarde 33, Amersfoort", "lat": 52.1955624, "lng": 5.3685034, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Schone van Boskoopgaarde 35, Amersfoort", "lat": 52.1954770, "lng": 5.3686036, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Schone van Boskoopgaarde 37, Amersfoort", "lat": 52.1954427, "lng": 5.3686370, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Schone van Boskoopgaarde 39, Amersfoort", "lat": 52.1953676, "lng": 5.3687651, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 41, Amersfoort", "lat": 52.1953402, "lng": 5.3687985, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Schone van Boskoopgaarde 43, Amersfoort", "lat": 52.1952752, "lng": 5.3689266, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Schone van Boskoopgaarde 45, Amersfoort", "lat": 52.1952444, "lng": 5.3689711, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Schone van Boskoopgaarde 47, Amersfoort", "lat": 52.1951863, "lng": 5.3691159, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Schone van Boskoopgaarde 49, Amersfoort", "lat": 52.1951657, "lng": 5.3691659, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Schone van Boskoopgaarde 51, Amersfoort", "lat": 52.1950461, "lng": 5.3694945, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Schone van Boskoopgaarde 53, Amersfoort", "lat": 52.1950256, "lng": 5.3695556, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Schone van Boskoopgaarde 55, Amersfoort", "lat": 52.1949983, "lng": 5.3698675, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Schone van Boskoopgaarde 57, Amersfoort", "lat": 52.1950120, "lng": 5.3699286, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Schone van Boskoopgaarde 59, Amersfoort", "lat": 52.1950667, "lng": 5.3701067, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Schone van Boskoopgaarde 61, Amersfoort", "lat": 52.1950975, "lng": 5.3701680, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 63, Amersfoort", "lat": 52.1952172, "lng": 5.3703183, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Schone van Boskoopgaarde 65, Amersfoort", "lat": 52.1952481, "lng": 5.3703405, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Schone van Boskoopgaarde 67, Amersfoort", "lat": 52.1953267, "lng": 5.3704129, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Schone van Boskoopgaarde 69, Amersfoort", "lat": 52.1953678, "lng": 5.3704406, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Schone van Boskoopgaarde 71, Amersfoort", "lat": 52.1954464, "lng": 5.3705186, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Schone van Boskoopgaarde 73, Amersfoort", "lat": 52.1954807, "lng": 5.3705519, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schone van Boskoopgaarde 75, Amersfoort", "lat": 52.1955628, "lng": 5.3706243, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Schone van Boskoopgaarde 77, Amersfoort", "lat": 52.1956004, "lng": 5.3706576, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Schone van Boskoopgaarde 79, Amersfoort", "lat": 52.1956860, "lng": 5.3707300, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Schone van Boskoopgaarde 81, Amersfoort", "lat": 52.1957202, "lng": 5.3707577, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Schone van Boskoopgaarde 83, Amersfoort", "lat": 52.1957955, "lng": 5.3708357, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Schone van Boskoopgaarde 85, Amersfoort", "lat": 52.1958331, "lng": 5.3708691, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Schorrekruid 1, Amersfoort", "lat": 52.2031659, "lng": 5.3823477, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 2, Amersfoort", "lat": 52.2030016, "lng": 5.3826079, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 3, Amersfoort", "lat": 52.2031920, "lng": 5.3824196, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 4, Amersfoort", "lat": 52.2030254, "lng": 5.3826855, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 5, Amersfoort", "lat": 52.2032170, "lng": 5.3824935, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 6, Amersfoort", "lat": 52.2030458, "lng": 5.3827574, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 7, Amersfoort", "lat": 52.2032419, "lng": 5.3825618, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 8, Amersfoort", "lat": 52.2030650, "lng": 5.3828312, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 9, Amersfoort", "lat": 52.2032657, "lng": 5.3826300, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 10, Amersfoort", "lat": 52.2030900, "lng": 5.3829031, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 11, Amersfoort", "lat": 52.2032895, "lng": 5.3827020, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 12, Amersfoort", "lat": 52.2031104, "lng": 5.3829770, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 13, Amersfoort", "lat": 52.2033168, "lng": 5.3827720, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 14, Amersfoort", "lat": 52.2031296, "lng": 5.3830507, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Schorrekruid 15, Amersfoort", "lat": 52.2033406, "lng": 5.3828440, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Sijsjespeergaarde 2, Amersfoort", "lat": 52.1983128, "lng": 5.3709851, "expected_has_charger": None},  # 220m², 1vbo
    {"adres": "Sijsjespeergaarde 4, Amersfoort", "lat": 52.1983507, "lng": 5.3711814, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 6, Amersfoort", "lat": 52.1983791, "lng": 5.3713699, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 8, Amersfoort", "lat": 52.1984052, "lng": 5.3715471, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 10, Amersfoort", "lat": 52.1984360, "lng": 5.3717394, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 12, Amersfoort", "lat": 52.1984620, "lng": 5.3719319, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 14, Amersfoort", "lat": 52.1984927, "lng": 5.3721204, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 16, Amersfoort", "lat": 52.1985212, "lng": 5.3723167, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 18, Amersfoort", "lat": 52.1985472, "lng": 5.3725091, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Sijsjespeergaarde 20, Amersfoort", "lat": 52.1985708, "lng": 5.3727054, "expected_has_charger": None},  # 214m², 1vbo
    {"adres": "Sijsjespeergaarde 22, Amersfoort", "lat": 52.1986063, "lng": 5.3728786, "expected_has_charger": None},  # 211m², 1vbo
    {"adres": "Sikkelkruid 1, Amersfoort", "lat": 52.2028168, "lng": 5.3835194, "expected_has_charger": None},  # 193m², 1vbo
    {"adres": "Sikkelkruid 2, Amersfoort", "lat": 52.2028962, "lng": 5.3839586, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Sikkelkruid 3, Amersfoort", "lat": 52.2028780, "lng": 5.3834899, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 4, Amersfoort", "lat": 52.2029687, "lng": 5.3839365, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Sikkelkruid 5, Amersfoort", "lat": 52.2029370, "lng": 5.3834714, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Sikkelkruid 6, Amersfoort", "lat": 52.2031615, "lng": 5.3838626, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "Sikkelkruid 7, Amersfoort", "lat": 52.2029982, "lng": 5.3834419, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 8, Amersfoort", "lat": 52.2032318, "lng": 5.3838257, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Sikkelkruid 9, Amersfoort", "lat": 52.2030549, "lng": 5.3834050, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 10, Amersfoort", "lat": 52.2034109, "lng": 5.3837113, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Sikkelkruid 11, Amersfoort", "lat": 52.2031092, "lng": 5.3833866, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Sikkelkruid 12, Amersfoort", "lat": 52.2034743, "lng": 5.3836633, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Sikkelkruid 13, Amersfoort", "lat": 52.2031637, "lng": 5.3833570, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 14, Amersfoort", "lat": 52.2036444, "lng": 5.3834862, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Sikkelkruid 15, Amersfoort", "lat": 52.2032227, "lng": 5.3833311, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 16, Amersfoort", "lat": 52.2037102, "lng": 5.3834197, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Sikkelkruid 17, Amersfoort", "lat": 52.2034426, "lng": 5.3831762, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 18, Amersfoort", "lat": 52.2038621, "lng": 5.3832019, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Sikkelkruid 19, Amersfoort", "lat": 52.2034901, "lng": 5.3831171, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 20, Amersfoort", "lat": 52.2039142, "lng": 5.3831097, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Sikkelkruid 21, Amersfoort", "lat": 52.2035424, "lng": 5.3830655, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Sikkelkruid 22, Amersfoort", "lat": 52.2040344, "lng": 5.3829141, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Sikkelkruid 23, Amersfoort", "lat": 52.2035809, "lng": 5.3829990, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 24, Amersfoort", "lat": 52.2040887, "lng": 5.3828218, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Sikkelkruid 25, Amersfoort", "lat": 52.2036285, "lng": 5.3829290, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 26, Amersfoort", "lat": 52.2043495, "lng": 5.3822092, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Sikkelkruid 27, Amersfoort", "lat": 52.2036761, "lng": 5.3828735, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Sikkelkruid 28, Amersfoort", "lat": 52.2045014, "lng": 5.3817959, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Sikkelkruid 29, Amersfoort", "lat": 52.2037147, "lng": 5.3827923, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 30, Amersfoort", "lat": 52.2046012, "lng": 5.3814748, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Sikkelkruid 31, Amersfoort", "lat": 52.2037510, "lng": 5.3827148, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Sikkelkruid 32, Amersfoort", "lat": 52.2047122, "lng": 5.3810577, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Sikkelkruid 33, Amersfoort", "lat": 52.2038031, "lng": 5.3826631, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Sikkelkruid 34, Amersfoort", "lat": 52.2047893, "lng": 5.3806997, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Sikkelkruid 35, Amersfoort", "lat": 52.2038326, "lng": 5.3825894, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 36, Amersfoort", "lat": 52.2048641, "lng": 5.3802421, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Sikkelkruid 37, Amersfoort", "lat": 52.2038824, "lng": 5.3825192, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 39, Amersfoort", "lat": 52.2040298, "lng": 5.3822019, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 41, Amersfoort", "lat": 52.2040615, "lng": 5.3821132, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 43, Amersfoort", "lat": 52.2041092, "lng": 5.3820468, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Sikkelkruid 45, Amersfoort", "lat": 52.2041296, "lng": 5.3819583, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 47, Amersfoort", "lat": 52.2041704, "lng": 5.3818844, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 49, Amersfoort", "lat": 52.2042157, "lng": 5.3818143, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Sikkelkruid 51, Amersfoort", "lat": 52.2042293, "lng": 5.3817184, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 53, Amersfoort", "lat": 52.2042633, "lng": 5.3816299, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 55, Amersfoort", "lat": 52.2042996, "lng": 5.3815596, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Sikkelkruid 57, Amersfoort", "lat": 52.2043132, "lng": 5.3814491, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 59, Amersfoort", "lat": 52.2043404, "lng": 5.3813715, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Sikkelkruid 61, Amersfoort", "lat": 52.2044311, "lng": 5.3810431, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 63, Amersfoort", "lat": 52.2044537, "lng": 5.3809508, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 65, Amersfoort", "lat": 52.2044764, "lng": 5.3808659, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Sikkelkruid 67, Amersfoort", "lat": 52.2044968, "lng": 5.3807625, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 69, Amersfoort", "lat": 52.2045127, "lng": 5.3806703, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 71, Amersfoort", "lat": 52.2045466, "lng": 5.3805817, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Sikkelkruid 73, Amersfoort", "lat": 52.2045581, "lng": 5.3804857, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sikkelkruid 75, Amersfoort", "lat": 52.2045784, "lng": 5.3804082, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Sneulseweg 2, Amersfoort", "lat": 52.1984033, "lng": 5.3812905, "expected_has_charger": None},  # 147m², 2vbo
    {"adres": "Speenkruid 1, Amersfoort", "lat": 52.2048023, "lng": 5.3795374, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Speenkruid 2, Amersfoort", "lat": 52.2048676, "lng": 5.3798382, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Speenkruid 3, Amersfoort", "lat": 52.2048372, "lng": 5.3794805, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Speenkruid 4, Amersfoort", "lat": 52.2049262, "lng": 5.3798601, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Speenkruid 5, Amersfoort", "lat": 52.2048800, "lng": 5.3794347, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Speenkruid 6, Amersfoort", "lat": 52.2049758, "lng": 5.3798565, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Speenkruid 7, Amersfoort", "lat": 52.2049194, "lng": 5.3793888, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Speenkruid 8, Amersfoort", "lat": 52.2050231, "lng": 5.3798509, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Speenkruid 9, Amersfoort", "lat": 52.2049588, "lng": 5.3793503, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Speenkruid 10, Amersfoort", "lat": 52.2050693, "lng": 5.3798455, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Speenkruid 11, Amersfoort", "lat": 52.2050040, "lng": 5.3793099, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Speenkruid 12, Amersfoort", "lat": 52.2051178, "lng": 5.3798382, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Speenkruid 13, Amersfoort", "lat": 52.2050467, "lng": 5.3792678, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Speenkruid 14, Amersfoort", "lat": 52.2051650, "lng": 5.3798307, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Speenkruid 15, Amersfoort", "lat": 52.2050929, "lng": 5.3792422, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Stalkruid 1, Amersfoort", "lat": 52.2048474, "lng": 5.3803608, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Stalkruid 2, Amersfoort", "lat": 52.2048113, "lng": 5.3805863, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Stalkruid 3, Amersfoort", "lat": 52.2049094, "lng": 5.3803076, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Stalkruid 4, Amersfoort", "lat": 52.2048463, "lng": 5.3806908, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Stalkruid 5, Amersfoort", "lat": 52.2049556, "lng": 5.3803223, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Stalkruid 6, Amersfoort", "lat": 52.2048925, "lng": 5.3807110, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Stalkruid 7, Amersfoort", "lat": 52.2050040, "lng": 5.3803351, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Stalkruid 8, Amersfoort", "lat": 52.2049365, "lng": 5.3807311, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Stalkruid 9, Amersfoort", "lat": 52.2050513, "lng": 5.3803497, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Stalkruid 10, Amersfoort", "lat": 52.2049849, "lng": 5.3807569, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Stalkruid 11, Amersfoort", "lat": 52.2050987, "lng": 5.3803626, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Stalkruid 12, Amersfoort", "lat": 52.2050344, "lng": 5.3807715, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Sterappelgaarde 1, Amersfoort", "lat": 52.1966692, "lng": 5.3726845, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Sterappelgaarde 2, Amersfoort", "lat": 52.1964336, "lng": 5.3723305, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 3, Amersfoort", "lat": 52.1966496, "lng": 5.3727670, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Sterappelgaarde 4, Amersfoort", "lat": 52.1963976, "lng": 5.3724157, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Sterappelgaarde 5, Amersfoort", "lat": 52.1966316, "lng": 5.3728416, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Sterappelgaarde 6, Amersfoort", "lat": 52.1963813, "lng": 5.3724770, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 7, Amersfoort", "lat": 52.1966054, "lng": 5.3729028, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Sterappelgaarde 8, Amersfoort", "lat": 52.1963698, "lng": 5.3726873, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 9, Amersfoort", "lat": 52.1965858, "lng": 5.3729826, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Sterappelgaarde 10, Amersfoort", "lat": 52.1963502, "lng": 5.3727619, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 11, Amersfoort", "lat": 52.1965629, "lng": 5.3730599, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Sterappelgaarde 12, Amersfoort", "lat": 52.1963028, "lng": 5.3729190, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 13, Amersfoort", "lat": 52.1965449, "lng": 5.3731371, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Sterappelgaarde 14, Amersfoort", "lat": 52.1962799, "lng": 5.3730041, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 15, Amersfoort", "lat": 52.1965286, "lng": 5.3732063, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Sterappelgaarde 16, Amersfoort", "lat": 52.1962424, "lng": 5.3731294, "expected_has_charger": None},  # 122m², 3vbo
    {"adres": "Sterappelgaarde 16, Amersfoort", "lat": 52.1962472, "lng": 5.3731692, "expected_has_charger": None},  # 179m², 3vbo
    {"adres": "Sterappelgaarde 17, Amersfoort", "lat": 52.1965106, "lng": 5.3732729, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Sterappelgaarde 18, Amersfoort", "lat": 52.1962308, "lng": 5.3732570, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 19, Amersfoort", "lat": 52.1964926, "lng": 5.3733529, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Sterappelgaarde 20, Amersfoort", "lat": 52.1961932, "lng": 5.3734328, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Sterappelgaarde 21, Amersfoort", "lat": 52.1964762, "lng": 5.3734354, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Sterappelgaarde 22, Amersfoort", "lat": 52.1961802, "lng": 5.3735153, "expected_has_charger": None},  # 167m², 1vbo
    {"adres": "Sterappelgaarde 23, Amersfoort", "lat": 52.1964632, "lng": 5.3735126, "expected_has_charger": None},  # 107m², 1vbo
    {"adres": "Sterappelgaarde 24, Amersfoort", "lat": 52.1961325, "lng": 5.3736819, "expected_has_charger": None},  # 123m², 2vbo
    {"adres": "Sterappelgaarde 25, Amersfoort", "lat": 52.1964501, "lng": 5.3735898, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Sterappelgaarde 26, Amersfoort", "lat": 52.1961343, "lng": 5.3737682, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 27, Amersfoort", "lat": 52.1964353, "lng": 5.3736590, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Sterappelgaarde 28, Amersfoort", "lat": 52.1961066, "lng": 5.3739572, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterappelgaarde 29, Amersfoort", "lat": 52.1964174, "lng": 5.3737389, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Sterappelgaarde 30, Amersfoort", "lat": 52.1960919, "lng": 5.3740398, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Sterappelgaarde 31, Amersfoort", "lat": 52.1964010, "lng": 5.3738187, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterappelgaarde 32, Amersfoort", "lat": 52.1960821, "lng": 5.3741197, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Sterrenkroos 1, Amersfoort", "lat": 52.2050656, "lng": 5.3744790, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Sterrenkroos 3, Amersfoort", "lat": 52.2050725, "lng": 5.3743915, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 5, Amersfoort", "lat": 52.2050794, "lng": 5.3743212, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 7, Amersfoort", "lat": 52.2050863, "lng": 5.3742422, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 9, Amersfoort", "lat": 52.2050898, "lng": 5.3741689, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 11, Amersfoort", "lat": 52.2050915, "lng": 5.3740899, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 13, Amersfoort", "lat": 52.2050967, "lng": 5.3740166, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 15, Amersfoort", "lat": 52.2051036, "lng": 5.3739461, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 17, Amersfoort", "lat": 52.2051070, "lng": 5.3738757, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 19, Amersfoort", "lat": 52.2051278, "lng": 5.3735458, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 21, Amersfoort", "lat": 52.2051278, "lng": 5.3734640, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 23, Amersfoort", "lat": 52.2051312, "lng": 5.3734020, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 25, Amersfoort", "lat": 52.2051347, "lng": 5.3733202, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 27, Amersfoort", "lat": 52.2051347, "lng": 5.3732469, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 29, Amersfoort", "lat": 52.2051347, "lng": 5.3731736, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 31, Amersfoort", "lat": 52.2051381, "lng": 5.3731003, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Sterrenkroos 33, Amersfoort", "lat": 52.2051416, "lng": 5.3730214, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 35, Amersfoort", "lat": 52.2051433, "lng": 5.3729538, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Sterrenkroos 37, Amersfoort", "lat": 52.2051502, "lng": 5.3727959, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Sterrenkroos 39, Amersfoort", "lat": 52.2051519, "lng": 5.3727282, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Sterrenkroos 41, Amersfoort", "lat": 52.2051554, "lng": 5.3726521, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Sterrenkroos 43, Amersfoort", "lat": 52.2051589, "lng": 5.3725731, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Sterrenkroos 45, Amersfoort", "lat": 52.2051589, "lng": 5.3725026, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 47, Amersfoort", "lat": 52.2051623, "lng": 5.3724238, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 49, Amersfoort", "lat": 52.2051640, "lng": 5.3723532, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Sterrenkroos 51, Amersfoort", "lat": 52.2051692, "lng": 5.3722772, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Sterrenkroos 53, Amersfoort", "lat": 52.2051709, "lng": 5.3721954, "expected_has_charger": None},  # 96m², 1vbo
    {"adres": "Suikerpeergaarde 1, Amersfoort", "lat": 52.1972005, "lng": 5.3724379, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Suikerpeergaarde 2, Amersfoort", "lat": 52.1974089, "lng": 5.3725582, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Suikerpeergaarde 3, Amersfoort", "lat": 52.1972542, "lng": 5.3723614, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Suikerpeergaarde 4, Amersfoort", "lat": 52.1974928, "lng": 5.3724214, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Suikerpeergaarde 5, Amersfoort", "lat": 52.1973012, "lng": 5.3722849, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Suikerpeergaarde 6, Amersfoort", "lat": 52.1981748, "lng": 5.3718581, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Suikerpeergaarde 7, Amersfoort", "lat": 52.1973483, "lng": 5.3722138, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Suikerpeergaarde 9, Amersfoort", "lat": 52.1973987, "lng": 5.3721427, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Suikerpeergaarde 11, Amersfoort", "lat": 52.1974558, "lng": 5.3720770, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Suikerpeergaarde 13, Amersfoort", "lat": 52.1975095, "lng": 5.3720169, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Suikerpeergaarde 15, Amersfoort", "lat": 52.1975633, "lng": 5.3719621, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Suikerpeergaarde 17, Amersfoort", "lat": 52.1976204, "lng": 5.3719130, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Suikerpeergaarde 19, Amersfoort", "lat": 52.1977985, "lng": 5.3717598, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Suikerpeergaarde 21, Amersfoort", "lat": 52.1978657, "lng": 5.3717160, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Suikerpeergaarde 23, Amersfoort", "lat": 52.1979295, "lng": 5.3716777, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Suikerpeergaarde 25, Amersfoort", "lat": 52.1979900, "lng": 5.3716503, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Suikerpeergaarde 27, Amersfoort", "lat": 52.1980505, "lng": 5.3716066, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Suikerpeergaarde 29, Amersfoort", "lat": 52.1981143, "lng": 5.3715902, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Suikerpeergaarde 31, Amersfoort", "lat": 52.1981848, "lng": 5.3715737, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Tasjeskruid 1, Amersfoort", "lat": 52.2046886, "lng": 5.3811604, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Tasjeskruid 2, Amersfoort", "lat": 52.2046379, "lng": 5.3813639, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Tasjeskruid 3, Amersfoort", "lat": 52.2047550, "lng": 5.3811200, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 4, Amersfoort", "lat": 52.2046604, "lng": 5.3814721, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 5, Amersfoort", "lat": 52.2047990, "lng": 5.3811475, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 6, Amersfoort", "lat": 52.2047055, "lng": 5.3815033, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 7, Amersfoort", "lat": 52.2048429, "lng": 5.3811786, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 8, Amersfoort", "lat": 52.2047505, "lng": 5.3815362, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 9, Amersfoort", "lat": 52.2048891, "lng": 5.3812042, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 10, Amersfoort", "lat": 52.2047911, "lng": 5.3815673, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 11, Amersfoort", "lat": 52.2049331, "lng": 5.3812354, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Tasjeskruid 12, Amersfoort", "lat": 52.2048340, "lng": 5.3815967, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Ton van Heugtenpad 1, Amersfoort", "lat": 52.1959841, "lng": 5.3851219, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 3, Amersfoort", "lat": 52.1959841, "lng": 5.3850411, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 5, Amersfoort", "lat": 52.1959841, "lng": 5.3849620, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 7, Amersfoort", "lat": 52.1959841, "lng": 5.3848831, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 9, Amersfoort", "lat": 52.1959841, "lng": 5.3848041, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 11, Amersfoort", "lat": 52.1959841, "lng": 5.3847252, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 13, Amersfoort", "lat": 52.1959841, "lng": 5.3846462, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 15, Amersfoort", "lat": 52.1959841, "lng": 5.3845671, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 17, Amersfoort", "lat": 52.1959841, "lng": 5.3844882, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 19, Amersfoort", "lat": 52.1959841, "lng": 5.3844092, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Ton van Heugtenpad 21, Amersfoort", "lat": 52.1959841, "lng": 5.3843286, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Trosjespeergaarde 1, Amersfoort", "lat": 52.1966998, "lng": 5.3718859, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 2, Amersfoort", "lat": 52.1969250, "lng": 5.3720991, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Trosjespeergaarde 3, Amersfoort", "lat": 52.1967300, "lng": 5.3718203, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Trosjespeergaarde 4, Amersfoort", "lat": 52.1969652, "lng": 5.3720334, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Trosjespeergaarde 5, Amersfoort", "lat": 52.1967670, "lng": 5.3717547, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 6, Amersfoort", "lat": 52.1969988, "lng": 5.3719733, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Trosjespeergaarde 7, Amersfoort", "lat": 52.1968476, "lng": 5.3716234, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 8, Amersfoort", "lat": 52.1970358, "lng": 5.3719132, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Trosjespeergaarde 9, Amersfoort", "lat": 52.1968879, "lng": 5.3715686, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 10, Amersfoort", "lat": 52.1970694, "lng": 5.3718529, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Trosjespeergaarde 11, Amersfoort", "lat": 52.1969652, "lng": 5.3714484, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 12, Amersfoort", "lat": 52.1971164, "lng": 5.3718037, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Trosjespeergaarde 13, Amersfoort", "lat": 52.1970055, "lng": 5.3714046, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 14, Amersfoort", "lat": 52.1971534, "lng": 5.3717490, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Trosjespeergaarde 15, Amersfoort", "lat": 52.1970962, "lng": 5.3712844, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Trosjespeergaarde 16, Amersfoort", "lat": 52.1971937, "lng": 5.3716943, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Trosjespeergaarde 17, Amersfoort", "lat": 52.1971903, "lng": 5.3711804, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 18, Amersfoort", "lat": 52.1972373, "lng": 5.3716452, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Trosjespeergaarde 19, Amersfoort", "lat": 52.1972305, "lng": 5.3711422, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 20, Amersfoort", "lat": 52.1972777, "lng": 5.3715959, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Trosjespeergaarde 21, Amersfoort", "lat": 52.1973246, "lng": 5.3710545, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Trosjespeergaarde 22, Amersfoort", "lat": 52.1973214, "lng": 5.3715521, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Trosjespeergaarde 23, Amersfoort", "lat": 52.1974758, "lng": 5.3709069, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Trosjespeergaarde 24, Amersfoort", "lat": 52.1973650, "lng": 5.3715029, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Trosjespeergaarde 25, Amersfoort", "lat": 52.1975665, "lng": 5.3708467, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 26, Amersfoort", "lat": 52.1974053, "lng": 5.3714592, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Trosjespeergaarde 27, Amersfoort", "lat": 52.1976135, "lng": 5.3708248, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Trosjespeergaarde 28, Amersfoort", "lat": 52.1976640, "lng": 5.3712513, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Trosjespeergaarde 29, Amersfoort", "lat": 52.1977076, "lng": 5.3707646, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Trosjespeergaarde 30, Amersfoort", "lat": 52.1977110, "lng": 5.3712185, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Trosjespeergaarde 31, Amersfoort", "lat": 52.1978051, "lng": 5.3707154, "expected_has_charger": None},  # 203m², 1vbo
    {"adres": "Trosjespeergaarde 32, Amersfoort", "lat": 52.1977648, "lng": 5.3711911, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Trosjespeergaarde 33, Amersfoort", "lat": 52.1978487, "lng": 5.3706881, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 34, Amersfoort", "lat": 52.1978119, "lng": 5.3711637, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Trosjespeergaarde 35, Amersfoort", "lat": 52.1979495, "lng": 5.3706443, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 36, Amersfoort", "lat": 52.1978555, "lng": 5.3711364, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Trosjespeergaarde 37, Amersfoort", "lat": 52.1980032, "lng": 5.3706223, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 38, Amersfoort", "lat": 52.1979059, "lng": 5.3711090, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Trosjespeergaarde 39, Amersfoort", "lat": 52.1981108, "lng": 5.3705841, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Trosjespeergaarde 40, Amersfoort", "lat": 52.1979563, "lng": 5.3710982, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Trosjespeergaarde 41, Amersfoort", "lat": 52.1981578, "lng": 5.3705676, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Trosjespeergaarde 42, Amersfoort", "lat": 52.1980067, "lng": 5.3710652, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Trosjespeergaarde 43, Amersfoort", "lat": 52.1982082, "lng": 5.3705458, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Trosjespeergaarde 44, Amersfoort", "lat": 52.1980537, "lng": 5.3710543, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Trosjespeergaarde 46, Amersfoort", "lat": 52.1981075, "lng": 5.3710378, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Tuinslak 2, Amersfoort", "lat": 52.2015471, "lng": 5.3695326, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 3, Amersfoort", "lat": 52.2018017, "lng": 5.3698229, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Tuinslak 4, Amersfoort", "lat": 52.2015471, "lng": 5.3696369, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 5, Amersfoort", "lat": 52.2017862, "lng": 5.3702345, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Tuinslak 6, Amersfoort", "lat": 52.2015436, "lng": 5.3697441, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Tuinslak 7, Amersfoort", "lat": 52.2018244, "lng": 5.3708828, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Tuinslak 8, Amersfoort", "lat": 52.2015436, "lng": 5.3698484, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 9, Amersfoort", "lat": 52.2018937, "lng": 5.3713084, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Tuinslak 10, Amersfoort", "lat": 52.2015384, "lng": 5.3699527, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Tuinslak 11, Amersfoort", "lat": 52.2020739, "lng": 5.3719399, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Tuinslak 12, Amersfoort", "lat": 52.2015384, "lng": 5.3700626, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 14, Amersfoort", "lat": 52.2015402, "lng": 5.3701669, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 16, Amersfoort", "lat": 52.2015351, "lng": 5.3702768, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 18, Amersfoort", "lat": 52.2015402, "lng": 5.3703784, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 20, Amersfoort", "lat": 52.2015437, "lng": 5.3704827, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 22, Amersfoort", "lat": 52.2015507, "lng": 5.3705870, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 24, Amersfoort", "lat": 52.2015559, "lng": 5.3707025, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 26, Amersfoort", "lat": 52.2015645, "lng": 5.3708125, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 28, Amersfoort", "lat": 52.2015733, "lng": 5.3709055, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 30, Amersfoort", "lat": 52.2015836, "lng": 5.3710098, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 32, Amersfoort", "lat": 52.2015975, "lng": 5.3711282, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 34, Amersfoort", "lat": 52.2016305, "lng": 5.3712917, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 36, Amersfoort", "lat": 52.2016495, "lng": 5.3713960, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 38, Amersfoort", "lat": 52.2016686, "lng": 5.3714778, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 40, Amersfoort", "lat": 52.2016946, "lng": 5.3715791, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 42, Amersfoort", "lat": 52.2017188, "lng": 5.3716976, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 44, Amersfoort", "lat": 52.2017449, "lng": 5.3717934, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 46, Amersfoort", "lat": 52.2017743, "lng": 5.3718864, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 48, Amersfoort", "lat": 52.2018055, "lng": 5.3719737, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 50, Amersfoort", "lat": 52.2018332, "lng": 5.3720697, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Tuinslak 52, Amersfoort", "lat": 52.2018713, "lng": 5.3721655, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 54, Amersfoort", "lat": 52.2019112, "lng": 5.3722585, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Tuinslak 56, Amersfoort", "lat": 52.2019475, "lng": 5.3723515, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Tuinslak 58, Amersfoort", "lat": 52.2019856, "lng": 5.3724445, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Valkruid 1, Amersfoort", "lat": 52.2044656, "lng": 5.3819066, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Valkruid 2, Amersfoort", "lat": 52.2043968, "lng": 5.3820974, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Valkruid 3, Amersfoort", "lat": 52.2045331, "lng": 5.3818791, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 4, Amersfoort", "lat": 52.2044103, "lng": 5.3822074, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 5, Amersfoort", "lat": 52.2045748, "lng": 5.3819122, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 6, Amersfoort", "lat": 52.2044532, "lng": 5.3822497, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 7, Amersfoort", "lat": 52.2046154, "lng": 5.3819525, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 8, Amersfoort", "lat": 52.2044914, "lng": 5.3822899, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 9, Amersfoort", "lat": 52.2046593, "lng": 5.3819947, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 10, Amersfoort", "lat": 52.2045309, "lng": 5.3823376, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 11, Amersfoort", "lat": 52.2046988, "lng": 5.3820277, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Valkruid 12, Amersfoort", "lat": 52.2045704, "lng": 5.3823762, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Vetkruid 1, Amersfoort", "lat": 52.2041951, "lng": 5.3825632, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Vetkruid 2, Amersfoort", "lat": 52.2041219, "lng": 5.3828970, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Vetkruid 3, Amersfoort", "lat": 52.2042458, "lng": 5.3825926, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Vetkruid 4, Amersfoort", "lat": 52.2041512, "lng": 5.3829373, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vetkruid 5, Amersfoort", "lat": 52.2042808, "lng": 5.3826366, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Vetkruid 6, Amersfoort", "lat": 52.2041827, "lng": 5.3829813, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vetkruid 7, Amersfoort", "lat": 52.2043236, "lng": 5.3826861, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Vetkruid 8, Amersfoort", "lat": 52.2042143, "lng": 5.3830216, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Vetkruid 9, Amersfoort", "lat": 52.2043619, "lng": 5.3827282, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Vetkruid 10, Amersfoort", "lat": 52.2042448, "lng": 5.3830674, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Vetkruid 11, Amersfoort", "lat": 52.2044013, "lng": 5.3827759, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Vetkruid 12, Amersfoort", "lat": 52.2042751, "lng": 5.3831134, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Vetkruid 13, Amersfoort", "lat": 52.2044408, "lng": 5.3828272, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Vetkruid 16, Amersfoort", "lat": 52.2043349, "lng": 5.3831903, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 1, Amersfoort", "lat": 52.2034516, "lng": 5.3837735, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 2, Amersfoort", "lat": 52.2032308, "lng": 5.3839202, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 3, Amersfoort", "lat": 52.2034718, "lng": 5.3838359, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 4, Amersfoort", "lat": 52.2032432, "lng": 5.3839844, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 6, Amersfoort", "lat": 52.2032544, "lng": 5.3840504, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 7, Amersfoort", "lat": 52.2035045, "lng": 5.3839569, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 8, Amersfoort", "lat": 52.2032623, "lng": 5.3841073, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 9, Amersfoort", "lat": 52.2035226, "lng": 5.3840156, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 10, Amersfoort", "lat": 52.2032770, "lng": 5.3841715, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 11, Amersfoort", "lat": 52.2035406, "lng": 5.3840742, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 12, Amersfoort", "lat": 52.2032894, "lng": 5.3842375, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Vijfvingerkruid 13, Amersfoort", "lat": 52.2035575, "lng": 5.3841329, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 14, Amersfoort", "lat": 52.2033006, "lng": 5.3842998, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vijfvingerkruid 15, Amersfoort", "lat": 52.2035744, "lng": 5.3841934, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Vijfvingerkruid 16, Amersfoort", "lat": 52.2033119, "lng": 5.3843640, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 1, Amersfoort", "lat": 52.2039169, "lng": 5.3832565, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 2, Amersfoort", "lat": 52.2037299, "lng": 5.3835040, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 3, Amersfoort", "lat": 52.2039428, "lng": 5.3832986, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 4, Amersfoort", "lat": 52.2037547, "lng": 5.3835644, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 6, Amersfoort", "lat": 52.2037726, "lng": 5.3836176, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Vingerhoedskruid 8, Amersfoort", "lat": 52.2037964, "lng": 5.3836690, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 9, Amersfoort", "lat": 52.2040296, "lng": 5.3834342, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 11, Amersfoort", "lat": 52.2040577, "lng": 5.3834893, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 12, Amersfoort", "lat": 52.2038426, "lng": 5.3837753, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 13, Amersfoort", "lat": 52.2040848, "lng": 5.3835369, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 14, Amersfoort", "lat": 52.2038673, "lng": 5.3838323, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Vingerhoedskruid 15, Amersfoort", "lat": 52.2041141, "lng": 5.3835828, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Vingerhoedskruid 16, Amersfoort", "lat": 52.2038888, "lng": 5.3838817, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Visotter 1, Amersfoort", "lat": 52.2006106, "lng": 5.3715299, "expected_has_charger": None},  # 199m², 1vbo
    {"adres": "Visotter 2, Amersfoort", "lat": 52.2005661, "lng": 5.3718778, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Visotter 3, Amersfoort", "lat": 52.2006620, "lng": 5.3712454, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Visotter 4, Amersfoort", "lat": 52.2006220, "lng": 5.3718463, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Visotter 5, Amersfoort", "lat": 52.2006119, "lng": 5.3710054, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Visotter 6, Amersfoort", "lat": 52.2006679, "lng": 5.3718243, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Visotter 7, Amersfoort", "lat": 52.2006691, "lng": 5.3707207, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Visotter 8, Amersfoort", "lat": 52.2007065, "lng": 5.3718052, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Visotter 9, Amersfoort", "lat": 52.2007651, "lng": 5.3703500, "expected_has_charger": None},  # 207m², 1vbo
    {"adres": "Visotter 10, Amersfoort", "lat": 52.2007467, "lng": 5.3717864, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Visotter 11, Amersfoort", "lat": 52.2008325, "lng": 5.3705878, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Visotter 13, Amersfoort", "lat": 52.2007924, "lng": 5.3708794, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Visotter 15, Amersfoort", "lat": 52.2008570, "lng": 5.3711147, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Visotter 17, Amersfoort", "lat": 52.2008427, "lng": 5.3713923, "expected_has_charger": None},  # 209m², 1vbo
    {"adres": "Vuursalamander 2, Amersfoort", "lat": 52.2003293, "lng": 5.3683813, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Vuursalamander 3, Amersfoort", "lat": 52.2000634, "lng": 5.3680892, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Vuursalamander 4, Amersfoort", "lat": 52.2003096, "lng": 5.3682516, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Vuursalamander 5, Amersfoort", "lat": 52.1992317, "lng": 5.3673586, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Vuursalamander 6, Amersfoort", "lat": 52.2002618, "lng": 5.3681297, "expected_has_charger": None},  # 184m², 1vbo
    {"adres": "Vuursalamander 7, Amersfoort", "lat": 52.1992087, "lng": 5.3674410, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Vuursalamander 8, Amersfoort", "lat": 52.2002247, "lng": 5.3680274, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Vuursalamander 9, Amersfoort", "lat": 52.1992017, "lng": 5.3675969, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Vuursalamander 10, Amersfoort", "lat": 52.2001733, "lng": 5.3679164, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Vuursalamander 11, Amersfoort", "lat": 52.1992116, "lng": 5.3676795, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Vuursalamander 12, Amersfoort", "lat": 52.2000970, "lng": 5.3678656, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Vuursalamander 14, Amersfoort", "lat": 52.2000333, "lng": 5.3677775, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Vuursalamander 16, Amersfoort", "lat": 52.1999754, "lng": 5.3677076, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 18, Amersfoort", "lat": 52.1999043, "lng": 5.3676254, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 20, Amersfoort", "lat": 52.1998593, "lng": 5.3675062, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Vuursalamander 22, Amersfoort", "lat": 52.1997913, "lng": 5.3674695, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 24, Amersfoort", "lat": 52.1997211, "lng": 5.3674119, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 26, Amersfoort", "lat": 52.1996522, "lng": 5.3673438, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 28, Amersfoort", "lat": 52.1995847, "lng": 5.3672849, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Vuursalamander 30, Amersfoort", "lat": 52.1995146, "lng": 5.3672113, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 32, Amersfoort", "lat": 52.1994372, "lng": 5.3671717, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 34, Amersfoort", "lat": 52.1993663, "lng": 5.3671018, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 36, Amersfoort", "lat": 52.1992845, "lng": 5.3670532, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 38, Amersfoort", "lat": 52.1992167, "lng": 5.3670086, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 40, Amersfoort", "lat": 52.1991405, "lng": 5.3669675, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Vuursalamander 42, Amersfoort", "lat": 52.1990507, "lng": 5.3669734, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Vuursalamander 44, Amersfoort", "lat": 52.1989813, "lng": 5.3669151, "expected_has_charger": None},  # 266m², 2vbo
    {"adres": "Vuursalamander 48, Amersfoort", "lat": 52.1988724, "lng": 5.3672517, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Vuursalamander 50, Amersfoort", "lat": 52.1988706, "lng": 5.3674038, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Vuursalamander 52, Amersfoort", "lat": 52.1988818, "lng": 5.3675529, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Vuursalamander 54, Amersfoort", "lat": 52.1988894, "lng": 5.3676684, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Vuursalamander 56, Amersfoort", "lat": 52.1988968, "lng": 5.3677627, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Vuursalamander 58, Amersfoort", "lat": 52.1989024, "lng": 5.3678692, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Vuursalamander 60, Amersfoort", "lat": 52.1989127, "lng": 5.3679472, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Vuursalamander 62, Amersfoort", "lat": 52.1989247, "lng": 5.3680453, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Vuursalamander 64, Amersfoort", "lat": 52.1989417, "lng": 5.3681217, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Vuursalamander 66, Amersfoort", "lat": 52.1989530, "lng": 5.3682403, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Vuursalamander 68, Amersfoort", "lat": 52.1989773, "lng": 5.3683408, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Vuursalamander 70, Amersfoort", "lat": 52.1989946, "lng": 5.3684525, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Vuursalamander 72, Amersfoort", "lat": 52.1990214, "lng": 5.3685346, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Vuursalamander 74, Amersfoort", "lat": 52.1990499, "lng": 5.3686042, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Vuursalamander 76, Amersfoort", "lat": 52.1991066, "lng": 5.3686185, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Vuursalamander 78, Amersfoort", "lat": 52.1991784, "lng": 5.3686343, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Vuursalamander 80, Amersfoort", "lat": 52.1992338, "lng": 5.3686379, "expected_has_charger": None},  # 175m², 1vbo
    {"adres": "Vuursalamander 82, Amersfoort", "lat": 52.1993119, "lng": 5.3685962, "expected_has_charger": None},  # 209m², 1vbo
    {"adres": "Waterdreef 2, Amersfoort", "lat": 52.2011659, "lng": 5.3691918, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Waterdreef 4, Amersfoort", "lat": 52.2012231, "lng": 5.3692058, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterdreef 6, Amersfoort", "lat": 52.2012734, "lng": 5.3691945, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterdreef 8, Amersfoort", "lat": 52.2013218, "lng": 5.3691973, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterdreef 10, Amersfoort", "lat": 52.2013790, "lng": 5.3692000, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterdreef 12, Amersfoort", "lat": 52.2014344, "lng": 5.3691972, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterdreef 14, Amersfoort", "lat": 52.2014829, "lng": 5.3691972, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterdreef 16, Amersfoort", "lat": 52.2015314, "lng": 5.3691972, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterdreef 18, Amersfoort", "lat": 52.2015903, "lng": 5.3692056, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Waterdreef 20, Amersfoort", "lat": 52.2017965, "lng": 5.3692338, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterdreef 22, Amersfoort", "lat": 52.2018380, "lng": 5.3692338, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 24, Amersfoort", "lat": 52.2018813, "lng": 5.3692421, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 26, Amersfoort", "lat": 52.2019280, "lng": 5.3692563, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 28, Amersfoort", "lat": 52.2019679, "lng": 5.3692703, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 30, Amersfoort", "lat": 52.2020164, "lng": 5.3692815, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 32, Amersfoort", "lat": 52.2020597, "lng": 5.3693040, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 34, Amersfoort", "lat": 52.2021012, "lng": 5.3693125, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 36, Amersfoort", "lat": 52.2021446, "lng": 5.3693407, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 38, Amersfoort", "lat": 52.2021914, "lng": 5.3693577, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 40, Amersfoort", "lat": 52.2022312, "lng": 5.3693830, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 42, Amersfoort", "lat": 52.2022693, "lng": 5.3694055, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 44, Amersfoort", "lat": 52.2023144, "lng": 5.3694309, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 46, Amersfoort", "lat": 52.2023525, "lng": 5.3694392, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 48, Amersfoort", "lat": 52.2024009, "lng": 5.3694732, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 50, Amersfoort", "lat": 52.2024356, "lng": 5.3694957, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 52, Amersfoort", "lat": 52.2024771, "lng": 5.3695182, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 54, Amersfoort", "lat": 52.2025205, "lng": 5.3695492, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 284, Amersfoort", "lat": 52.2041270, "lng": 5.3722493, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 286, Amersfoort", "lat": 52.2041343, "lng": 5.3723072, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 288, Amersfoort", "lat": 52.2041454, "lng": 5.3723713, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 290, Amersfoort", "lat": 52.2041540, "lng": 5.3724333, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 292, Amersfoort", "lat": 52.2041627, "lng": 5.3725154, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 294, Amersfoort", "lat": 52.2041725, "lng": 5.3725793, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 296, Amersfoort", "lat": 52.2041824, "lng": 5.3726514, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 298, Amersfoort", "lat": 52.2041898, "lng": 5.3727215, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Waterdreef 300, Amersfoort", "lat": 52.2041959, "lng": 5.3727974, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Waterdreef 302, Amersfoort", "lat": 52.2042033, "lng": 5.3728695, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Waterdreef 304, Amersfoort", "lat": 52.2042082, "lng": 5.3729336, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 306, Amersfoort", "lat": 52.2042143, "lng": 5.3730076, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Waterdreef 308, Amersfoort", "lat": 52.2042180, "lng": 5.3730775, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 310, Amersfoort", "lat": 52.2042187, "lng": 5.3731577, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 312, Amersfoort", "lat": 52.2042212, "lng": 5.3732216, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 314, Amersfoort", "lat": 52.2042249, "lng": 5.3732917, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 316, Amersfoort", "lat": 52.2042236, "lng": 5.3733657, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterdreef 318, Amersfoort", "lat": 52.2042224, "lng": 5.3734498, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Waterdreef 320, Amersfoort", "lat": 52.2042181, "lng": 5.3737779, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Waterdreef 322, Amersfoort", "lat": 52.2042144, "lng": 5.3738660, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Waterdreef 324, Amersfoort", "lat": 52.2042059, "lng": 5.3739560, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Waterdreef 326, Amersfoort", "lat": 52.2042022, "lng": 5.3740440, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Waterdreef 328, Amersfoort", "lat": 52.2041949, "lng": 5.3741301, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Waterdreef 330, Amersfoort", "lat": 52.2041912, "lng": 5.3742102, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Waterdreef 332, Amersfoort", "lat": 52.2041837, "lng": 5.3742902, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Waterdreef 334, Amersfoort", "lat": 52.2041752, "lng": 5.3743862, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Waterdreef 336, Amersfoort", "lat": 52.2041642, "lng": 5.3744623, "expected_has_charger": None},  # 154m², 1vbo
    {"adres": "Waterdreef 338, Amersfoort", "lat": 52.2041494, "lng": 5.3745504, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Waterdreef 340, Amersfoort", "lat": 52.2041015, "lng": 5.3750466, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Waterdreef 342, Amersfoort", "lat": 52.2040941, "lng": 5.3751286, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 344, Amersfoort", "lat": 52.2040831, "lng": 5.3752167, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 346, Amersfoort", "lat": 52.2040732, "lng": 5.3753147, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 348, Amersfoort", "lat": 52.2040610, "lng": 5.3753868, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 350, Amersfoort", "lat": 52.2040548, "lng": 5.3754748, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 352, Amersfoort", "lat": 52.2040462, "lng": 5.3755548, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 354, Amersfoort", "lat": 52.2040327, "lng": 5.3756530, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 356, Amersfoort", "lat": 52.2040192, "lng": 5.3757350, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 358, Amersfoort", "lat": 52.2040069, "lng": 5.3758169, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 360, Amersfoort", "lat": 52.2039959, "lng": 5.3758891, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 362, Amersfoort", "lat": 52.2039847, "lng": 5.3759771, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 364, Amersfoort", "lat": 52.2039676, "lng": 5.3760652, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 366, Amersfoort", "lat": 52.2039529, "lng": 5.3761392, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Waterdreef 368, Amersfoort", "lat": 52.2039049, "lng": 5.3765033, "expected_has_charger": None},  # 172m², 1vbo
    {"adres": "Waterdreef 370, Amersfoort", "lat": 52.2038877, "lng": 5.3765875, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 372, Amersfoort", "lat": 52.2038730, "lng": 5.3766754, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Waterdreef 374, Amersfoort", "lat": 52.2038619, "lng": 5.3767454, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 376, Amersfoort", "lat": 52.2038521, "lng": 5.3768356, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 378, Amersfoort", "lat": 52.2038336, "lng": 5.3769236, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 380, Amersfoort", "lat": 52.2038226, "lng": 5.3770115, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 382, Amersfoort", "lat": 52.2038079, "lng": 5.3770857, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 384, Amersfoort", "lat": 52.2037882, "lng": 5.3771757, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 386, Amersfoort", "lat": 52.2037784, "lng": 5.3772518, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 388, Amersfoort", "lat": 52.2037587, "lng": 5.3773318, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 390, Amersfoort", "lat": 52.2037427, "lng": 5.3774238, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 392, Amersfoort", "lat": 52.2037231, "lng": 5.3775119, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 394, Amersfoort", "lat": 52.2037071, "lng": 5.3775859, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 396, Amersfoort", "lat": 52.2036923, "lng": 5.3776659, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 398, Amersfoort", "lat": 52.2036739, "lng": 5.3777440, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 400, Amersfoort", "lat": 52.2036549, "lng": 5.3778280, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterdreef 402, Amersfoort", "lat": 52.2036352, "lng": 5.3779082, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Waterdrieblad 1, Amersfoort", "lat": 52.2034798, "lng": 5.3763649, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 2, Amersfoort", "lat": 52.2032565, "lng": 5.3763056, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 3, Amersfoort", "lat": 52.2034593, "lng": 5.3765361, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 4, Amersfoort", "lat": 52.2032333, "lng": 5.3764617, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 5, Amersfoort", "lat": 52.2034472, "lng": 5.3766401, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 6, Amersfoort", "lat": 52.2032179, "lng": 5.3765500, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 7, Amersfoort", "lat": 52.2034284, "lng": 5.3767948, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Waterdrieblad 8, Amersfoort", "lat": 52.2031964, "lng": 5.3767250, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 9, Amersfoort", "lat": 52.2034128, "lng": 5.3768911, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 10, Amersfoort", "lat": 52.2031816, "lng": 5.3768182, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 11, Amersfoort", "lat": 52.2033884, "lng": 5.3770526, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 12, Amersfoort", "lat": 52.2031618, "lng": 5.3769757, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 13, Amersfoort", "lat": 52.2033802, "lng": 5.3771527, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 14, Amersfoort", "lat": 52.2031419, "lng": 5.3770644, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 15, Amersfoort", "lat": 52.2033532, "lng": 5.3773114, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 16, Amersfoort", "lat": 52.2031210, "lng": 5.3772317, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 17, Amersfoort", "lat": 52.2033433, "lng": 5.3774125, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 18, Amersfoort", "lat": 52.2031019, "lng": 5.3773242, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 19, Amersfoort", "lat": 52.2033229, "lng": 5.3775718, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 20, Amersfoort", "lat": 52.2030824, "lng": 5.3774842, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterdrieblad 21, Amersfoort", "lat": 52.2032996, "lng": 5.3777422, "expected_has_charger": None},  # 194m², 1vbo
    {"adres": "Waterdrieblad 22, Amersfoort", "lat": 52.2030654, "lng": 5.3776653, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Watergentiaan 1, Amersfoort", "lat": 52.2035335, "lng": 5.3760608, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 2, Amersfoort", "lat": 52.2035679, "lng": 5.3758930, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 3, Amersfoort", "lat": 52.2035750, "lng": 5.3758093, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 4, Amersfoort", "lat": 52.2035992, "lng": 5.3756517, "expected_has_charger": None},  # 198m², 1vbo
    {"adres": "Watergentiaan 5, Amersfoort", "lat": 52.2036404, "lng": 5.3755771, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 6, Amersfoort", "lat": 52.2036601, "lng": 5.3754105, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 7, Amersfoort", "lat": 52.2037439, "lng": 5.3752567, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Watergentiaan 8, Amersfoort", "lat": 52.2036279, "lng": 5.3750925, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Watergentiaan 9, Amersfoort", "lat": 52.2035119, "lng": 5.3750366, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Watergentiaan 10, Amersfoort", "lat": 52.2033874, "lng": 5.3750052, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Watergentiaan 11, Amersfoort", "lat": 52.2032714, "lng": 5.3750926, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Watergentiaan 12, Amersfoort", "lat": 52.2033273, "lng": 5.3753004, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 13, Amersfoort", "lat": 52.2033130, "lng": 5.3754390, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 14, Amersfoort", "lat": 52.2033210, "lng": 5.3755601, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 15, Amersfoort", "lat": 52.2033068, "lng": 5.3757052, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 16, Amersfoort", "lat": 52.2032966, "lng": 5.3758209, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watergentiaan 17, Amersfoort", "lat": 52.2032742, "lng": 5.3759655, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterjuffer 1, Amersfoort", "lat": 52.2039297, "lng": 5.3721553, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 3, Amersfoort", "lat": 52.2038842, "lng": 5.3721692, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 5, Amersfoort", "lat": 52.2038436, "lng": 5.3721812, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 7, Amersfoort", "lat": 52.2038018, "lng": 5.3721812, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 9, Amersfoort", "lat": 52.2037539, "lng": 5.3721913, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 11, Amersfoort", "lat": 52.2035608, "lng": 5.3721753, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 13, Amersfoort", "lat": 52.2035178, "lng": 5.3721633, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 15, Amersfoort", "lat": 52.2034748, "lng": 5.3721474, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 17, Amersfoort", "lat": 52.2034268, "lng": 5.3721334, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 19, Amersfoort", "lat": 52.2033900, "lng": 5.3721174, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 21, Amersfoort", "lat": 52.2033482, "lng": 5.3721055, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 23, Amersfoort", "lat": 52.2031674, "lng": 5.3719753, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 25, Amersfoort", "lat": 52.2031293, "lng": 5.3719393, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterjuffer 27, Amersfoort", "lat": 52.2030887, "lng": 5.3719073, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Waterjuffer 29, Amersfoort", "lat": 52.2030555, "lng": 5.3718714, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Waterjuffer 31, Amersfoort", "lat": 52.2030149, "lng": 5.3718294, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Waterjuffer 33, Amersfoort", "lat": 52.2029854, "lng": 5.3717833, "expected_has_charger": None},  # 135m², 1vbo
    {"adres": "Waterlelie 1, Amersfoort", "lat": 52.2028570, "lng": 5.3762707, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 2, Amersfoort", "lat": 52.2028499, "lng": 5.3763658, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 3, Amersfoort", "lat": 52.2028407, "lng": 5.3764620, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 4, Amersfoort", "lat": 52.2028341, "lng": 5.3765620, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 5, Amersfoort", "lat": 52.2028214, "lng": 5.3766611, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 6, Amersfoort", "lat": 52.2028114, "lng": 5.3767736, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 7, Amersfoort", "lat": 52.2028081, "lng": 5.3768712, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 8, Amersfoort", "lat": 52.2027944, "lng": 5.3769799, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 9, Amersfoort", "lat": 52.2027895, "lng": 5.3770827, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 10, Amersfoort", "lat": 52.2027787, "lng": 5.3771841, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 11, Amersfoort", "lat": 52.2027669, "lng": 5.3772913, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Waterlelie 12, Amersfoort", "lat": 52.2027991, "lng": 5.3774312, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterlelie 13, Amersfoort", "lat": 52.2027452, "lng": 5.3775530, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterlelie 14, Amersfoort", "lat": 52.2026623, "lng": 5.3776072, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterlelie 15, Amersfoort", "lat": 52.2025838, "lng": 5.3775853, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterlelie 16, Amersfoort", "lat": 52.2025287, "lng": 5.3775108, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterlelie 17, Amersfoort", "lat": 52.2024834, "lng": 5.3773858, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterlelie 18, Amersfoort", "lat": 52.2025349, "lng": 5.3772460, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Waterlelie 19, Amersfoort", "lat": 52.2025478, "lng": 5.3771341, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 20, Amersfoort", "lat": 52.2025517, "lng": 5.3770335, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 21, Amersfoort", "lat": 52.2025609, "lng": 5.3769286, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 22, Amersfoort", "lat": 52.2025710, "lng": 5.3768247, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 23, Amersfoort", "lat": 52.2025778, "lng": 5.3767248, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 24, Amersfoort", "lat": 52.2025865, "lng": 5.3766224, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 25, Amersfoort", "lat": 52.2026006, "lng": 5.3765082, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 26, Amersfoort", "lat": 52.2026041, "lng": 5.3764058, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterlelie 27, Amersfoort", "lat": 52.2026143, "lng": 5.3763057, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 1, Amersfoort", "lat": 52.2028935, "lng": 5.3758687, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Watermunt 2, Amersfoort", "lat": 52.2029020, "lng": 5.3757394, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 3, Amersfoort", "lat": 52.2029074, "lng": 5.3756529, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Watermunt 4, Amersfoort", "lat": 52.2029160, "lng": 5.3755571, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 5, Amersfoort", "lat": 52.2029269, "lng": 5.3754361, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 6, Amersfoort", "lat": 52.2029334, "lng": 5.3753449, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 7, Amersfoort", "lat": 52.2029434, "lng": 5.3752366, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Watermunt 8, Amersfoort", "lat": 52.2029493, "lng": 5.3751415, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Watermunt 9, Amersfoort", "lat": 52.2029964, "lng": 5.3750018, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Watermunt 10, Amersfoort", "lat": 52.2029643, "lng": 5.3749073, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Watermunt 11, Amersfoort", "lat": 52.2028966, "lng": 5.3747894, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Watermunt 12, Amersfoort", "lat": 52.2028150, "lng": 5.3747716, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Watermunt 13, Amersfoort", "lat": 52.2027495, "lng": 5.3748212, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Watermunt 14, Amersfoort", "lat": 52.2026958, "lng": 5.3749424, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Watermunt 15, Amersfoort", "lat": 52.2027108, "lng": 5.3750927, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 16, Amersfoort", "lat": 52.2027044, "lng": 5.3751765, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 17, Amersfoort", "lat": 52.2026933, "lng": 5.3752908, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 18, Amersfoort", "lat": 52.2026849, "lng": 5.3753964, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 19, Amersfoort", "lat": 52.2026762, "lng": 5.3754935, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 20, Amersfoort", "lat": 52.2026742, "lng": 5.3755977, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 21, Amersfoort", "lat": 52.2026656, "lng": 5.3757058, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Watermunt 22, Amersfoort", "lat": 52.2026564, "lng": 5.3758113, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Watermunt 23, Amersfoort", "lat": 52.2026444, "lng": 5.3759002, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Waterscheerling 1, Amersfoort", "lat": 52.2022642, "lng": 5.3761554, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterscheerling 2, Amersfoort", "lat": 52.2020623, "lng": 5.3760682, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "Waterscheerling 3, Amersfoort", "lat": 52.2022578, "lng": 5.3762498, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Waterscheerling 4, Amersfoort", "lat": 52.2020537, "lng": 5.3761451, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 5, Amersfoort", "lat": 52.2022514, "lng": 5.3763443, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Waterscheerling 6, Amersfoort", "lat": 52.2020456, "lng": 5.3762095, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 7, Amersfoort", "lat": 52.2022471, "lng": 5.3764211, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Waterscheerling 8, Amersfoort", "lat": 52.2020395, "lng": 5.3762814, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Waterscheerling 9, Amersfoort", "lat": 52.2022406, "lng": 5.3764980, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Waterscheerling 10, Amersfoort", "lat": 52.2020344, "lng": 5.3763569, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 11, Amersfoort", "lat": 52.2022299, "lng": 5.3765871, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Waterscheerling 12, Amersfoort", "lat": 52.2020271, "lng": 5.3764336, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 13, Amersfoort", "lat": 52.2022234, "lng": 5.3766689, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Waterscheerling 14, Amersfoort", "lat": 52.2020237, "lng": 5.3765041, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 15, Amersfoort", "lat": 52.2022222, "lng": 5.3767552, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterscheerling 16, Amersfoort", "lat": 52.2020166, "lng": 5.3765835, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 17, Amersfoort", "lat": 52.2022112, "lng": 5.3768349, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterscheerling 18, Amersfoort", "lat": 52.2020117, "lng": 5.3766555, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Waterscheerling 19, Amersfoort", "lat": 52.2022026, "lng": 5.3769164, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 20, Amersfoort", "lat": 52.2020044, "lng": 5.3767276, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 21, Amersfoort", "lat": 52.2021992, "lng": 5.3770002, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterscheerling 22, Amersfoort", "lat": 52.2019973, "lng": 5.3768054, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Waterscheerling 23, Amersfoort", "lat": 52.2021906, "lng": 5.3770852, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Waterscheerling 24, Amersfoort", "lat": 52.2019901, "lng": 5.3768733, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Waterscheerling 25, Amersfoort", "lat": 52.2021827, "lng": 5.3771673, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Waterscheerling 26, Amersfoort", "lat": 52.2019819, "lng": 5.3769511, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Waterscheerling 27, Amersfoort", "lat": 52.2022741, "lng": 5.3774910, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 28, Amersfoort", "lat": 52.2019808, "lng": 5.3770329, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Waterscheerling 29, Amersfoort", "lat": 52.2022325, "lng": 5.3774592, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 30, Amersfoort", "lat": 52.2016049, "lng": 5.3769386, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Waterscheerling 31, Amersfoort", "lat": 52.2021850, "lng": 5.3774582, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 32, Amersfoort", "lat": 52.2016136, "lng": 5.3768617, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Waterscheerling 33, Amersfoort", "lat": 52.2021436, "lng": 5.3774477, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 34, Amersfoort", "lat": 52.2016178, "lng": 5.3767882, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 35, Amersfoort", "lat": 52.2021000, "lng": 5.3774382, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 36, Amersfoort", "lat": 52.2016211, "lng": 5.3767191, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 37, Amersfoort", "lat": 52.2020543, "lng": 5.3774229, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 38, Amersfoort", "lat": 52.2016288, "lng": 5.3766443, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 39, Amersfoort", "lat": 52.2020115, "lng": 5.3774221, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 40, Amersfoort", "lat": 52.2016330, "lng": 5.3765639, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Waterscheerling 41, Amersfoort", "lat": 52.2019694, "lng": 5.3774153, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 42, Amersfoort", "lat": 52.2016401, "lng": 5.3764980, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 43, Amersfoort", "lat": 52.2019249, "lng": 5.3774047, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 44, Amersfoort", "lat": 52.2016451, "lng": 5.3764163, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 45, Amersfoort", "lat": 52.2018837, "lng": 5.3773894, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 46, Amersfoort", "lat": 52.2016486, "lng": 5.3763495, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 47, Amersfoort", "lat": 52.2018422, "lng": 5.3773814, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 48, Amersfoort", "lat": 52.2016578, "lng": 5.3762739, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 49, Amersfoort", "lat": 52.2017995, "lng": 5.3773834, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 50, Amersfoort", "lat": 52.2016616, "lng": 5.3761946, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Waterscheerling 51, Amersfoort", "lat": 52.2017574, "lng": 5.3773764, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 52, Amersfoort", "lat": 52.2016708, "lng": 5.3761303, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 53, Amersfoort", "lat": 52.2017112, "lng": 5.3773597, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Waterscheerling 54, Amersfoort", "lat": 52.2016739, "lng": 5.3760485, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterscheerling 55, Amersfoort", "lat": 52.2016620, "lng": 5.3773520, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 56, Amersfoort", "lat": 52.2016779, "lng": 5.3759669, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "Waterscheerling 57, Amersfoort", "lat": 52.2016231, "lng": 5.3773526, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 59, Amersfoort", "lat": 52.2015827, "lng": 5.3773397, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 61, Amersfoort", "lat": 52.2015428, "lng": 5.3773327, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 63, Amersfoort", "lat": 52.2015000, "lng": 5.3773153, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 65, Amersfoort", "lat": 52.2014547, "lng": 5.3773083, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 67, Amersfoort", "lat": 52.2014094, "lng": 5.3772930, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 69, Amersfoort", "lat": 52.2013698, "lng": 5.3772880, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 71, Amersfoort", "lat": 52.2013308, "lng": 5.3772786, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 73, Amersfoort", "lat": 52.2012866, "lng": 5.3772643, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 75, Amersfoort", "lat": 52.2012418, "lng": 5.3772623, "expected_has_charger": None},  # 138m², 1vbo
    {"adres": "Waterscheerling 77, Amersfoort", "lat": 52.2013794, "lng": 5.3769666, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Waterscheerling 79, Amersfoort", "lat": 52.2013820, "lng": 5.3768879, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Waterscheerling 81, Amersfoort", "lat": 52.2013863, "lng": 5.3768200, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 83, Amersfoort", "lat": 52.2013889, "lng": 5.3767400, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 85, Amersfoort", "lat": 52.2013975, "lng": 5.3766583, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Waterscheerling 87, Amersfoort", "lat": 52.2014083, "lng": 5.3765757, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Waterscheerling 89, Amersfoort", "lat": 52.2014118, "lng": 5.3764943, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Waterscheerling 91, Amersfoort", "lat": 52.2014220, "lng": 5.3764198, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 93, Amersfoort", "lat": 52.2014301, "lng": 5.3763290, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 95, Amersfoort", "lat": 52.2014322, "lng": 5.3762437, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 97, Amersfoort", "lat": 52.2014430, "lng": 5.3761594, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 99, Amersfoort", "lat": 52.2014486, "lng": 5.3760867, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterscheerling 101, Amersfoort", "lat": 52.2014543, "lng": 5.3759941, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Waterschorpioen 1, Amersfoort", "lat": 52.2035118, "lng": 5.3733078, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 2, Amersfoort", "lat": 52.2037220, "lng": 5.3733278, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 3, Amersfoort", "lat": 52.2035130, "lng": 5.3732338, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Waterschorpioen 4, Amersfoort", "lat": 52.2037244, "lng": 5.3732358, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Waterschorpioen 5, Amersfoort", "lat": 52.2035180, "lng": 5.3731519, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 6, Amersfoort", "lat": 52.2037257, "lng": 5.3731798, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Waterschorpioen 7, Amersfoort", "lat": 52.2035241, "lng": 5.3730858, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 8, Amersfoort", "lat": 52.2037282, "lng": 5.3730998, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Waterschorpioen 9, Amersfoort", "lat": 52.2035290, "lng": 5.3730018, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 10, Amersfoort", "lat": 52.2037282, "lng": 5.3730258, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Waterschorpioen 11, Amersfoort", "lat": 52.2035351, "lng": 5.3729318, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 12, Amersfoort", "lat": 52.2037293, "lng": 5.3729497, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Waterschorpioen 13, Amersfoort", "lat": 52.2035375, "lng": 5.3728617, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Waterschorpioen 14, Amersfoort", "lat": 52.2037293, "lng": 5.3728697, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Waterschorpioen 15, Amersfoort", "lat": 52.2035437, "lng": 5.3727796, "expected_has_charger": None},  # 104m², 1vbo
    {"adres": "Waterschorpioen 16, Amersfoort", "lat": 52.2037306, "lng": 5.3727956, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Waterschorpioen 17, Amersfoort", "lat": 52.2035474, "lng": 5.3727076, "expected_has_charger": None},  # 132m², 1vbo
    {"adres": "Waterschorpioen 18, Amersfoort", "lat": 52.2037343, "lng": 5.3727316, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 19, Amersfoort", "lat": 52.2035474, "lng": 5.3726456, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Waterschorpioen 20, Amersfoort", "lat": 52.2037342, "lng": 5.3726596, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 21, Amersfoort", "lat": 52.2035535, "lng": 5.3725656, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 22, Amersfoort", "lat": 52.2037355, "lng": 5.3725775, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Waterschorpioen 23, Amersfoort", "lat": 52.2035597, "lng": 5.3724895, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Waterschorpioen 24, Amersfoort", "lat": 52.2037342, "lng": 5.3725155, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Waterschorpioen 25, Amersfoort", "lat": 52.2036162, "lng": 5.3722714, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterschorpioen 26, Amersfoort", "lat": 52.2037035, "lng": 5.3722774, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterspin 1, Amersfoort", "lat": 52.2024888, "lng": 5.3726999, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Waterspin 2, Amersfoort", "lat": 52.2021828, "lng": 5.3727581, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 3, Amersfoort", "lat": 52.2028454, "lng": 5.3730740, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Waterspin 4, Amersfoort", "lat": 52.2022283, "lng": 5.3728421, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 5, Amersfoort", "lat": 52.2030913, "lng": 5.3732501, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Waterspin 6, Amersfoort", "lat": 52.2022762, "lng": 5.3729201, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Waterspin 8, Amersfoort", "lat": 52.2023254, "lng": 5.3730002, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterspin 9, Amersfoort", "lat": 52.2034811, "lng": 5.3733940, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Waterspin 10, Amersfoort", "lat": 52.2023795, "lng": 5.3730601, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 11, Amersfoort", "lat": 52.2037417, "lng": 5.3734059, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Waterspin 12, Amersfoort", "lat": 52.2024312, "lng": 5.3731262, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 14, Amersfoort", "lat": 52.2024815, "lng": 5.3731802, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 16, Amersfoort", "lat": 52.2025418, "lng": 5.3732382, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 18, Amersfoort", "lat": 52.2025984, "lng": 5.3733042, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 20, Amersfoort", "lat": 52.2026536, "lng": 5.3733602, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 22, Amersfoort", "lat": 52.2027114, "lng": 5.3734142, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 24, Amersfoort", "lat": 52.2027681, "lng": 5.3734563, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 26, Amersfoort", "lat": 52.2028246, "lng": 5.3734982, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 28, Amersfoort", "lat": 52.2029266, "lng": 5.3735683, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 30, Amersfoort", "lat": 52.2029857, "lng": 5.3735902, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 32, Amersfoort", "lat": 52.2030472, "lng": 5.3736362, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 34, Amersfoort", "lat": 52.2031160, "lng": 5.3736683, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 36, Amersfoort", "lat": 52.2031750, "lng": 5.3736922, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterspin 38, Amersfoort", "lat": 52.2032463, "lng": 5.3737183, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterspin 40, Amersfoort", "lat": 52.2033040, "lng": 5.3737482, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterspin 42, Amersfoort", "lat": 52.2033717, "lng": 5.3737561, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterspin 44, Amersfoort", "lat": 52.2034393, "lng": 5.3737742, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 46, Amersfoort", "lat": 52.2035032, "lng": 5.3737742, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 48, Amersfoort", "lat": 52.2035709, "lng": 5.3737841, "expected_has_charger": None},  # 190m², 1vbo
    {"adres": "Waterspin 50, Amersfoort", "lat": 52.2036361, "lng": 5.3737901, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterspin 52, Amersfoort", "lat": 52.2036963, "lng": 5.3737880, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 54, Amersfoort", "lat": 52.2037627, "lng": 5.3737961, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 56, Amersfoort", "lat": 52.2038217, "lng": 5.3737961, "expected_has_charger": None},  # 181m², 1vbo
    {"adres": "Waterspin 58, Amersfoort", "lat": 52.2038954, "lng": 5.3737921, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Waterspin 60, Amersfoort", "lat": 52.2039630, "lng": 5.3738060, "expected_has_charger": None},  # 192m², 1vbo
    {"adres": "Waterspringstaart 1, Amersfoort", "lat": 52.2019443, "lng": 5.3731644, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Waterspringstaart 2, Amersfoort", "lat": 52.2020314, "lng": 5.3732600, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Waterspringstaart 3, Amersfoort", "lat": 52.2020896, "lng": 5.3733444, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Waterspringstaart 4, Amersfoort", "lat": 52.2021398, "lng": 5.3734564, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterspringstaart 5, Amersfoort", "lat": 52.2022013, "lng": 5.3735264, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Waterspringstaart 6, Amersfoort", "lat": 52.2022750, "lng": 5.3736125, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterspringstaart 7, Amersfoort", "lat": 52.2023230, "lng": 5.3736665, "expected_has_charger": None},  # 155m², 1vbo
    {"adres": "Waterspringstaart 8, Amersfoort", "lat": 52.2024079, "lng": 5.3737605, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterspringstaart 9, Amersfoort", "lat": 52.2024546, "lng": 5.3738004, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Waterspringstaart 10, Amersfoort", "lat": 52.2025456, "lng": 5.3738746, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Waterspringstaart 11, Amersfoort", "lat": 52.2026034, "lng": 5.3739246, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Waterspringstaart 12, Amersfoort", "lat": 52.2026907, "lng": 5.3739965, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Waterspringstaart 13, Amersfoort", "lat": 52.2028074, "lng": 5.3740785, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Waterspringstaart 14, Amersfoort", "lat": 52.2029095, "lng": 5.3741345, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Waterspringstaart 15, Amersfoort", "lat": 52.2029501, "lng": 5.3741625, "expected_has_charger": None},  # 187m², 1vbo
    {"adres": "Waterspringstaart 16, Amersfoort", "lat": 52.2030635, "lng": 5.3741645, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Waterspringstaart 17, Amersfoort", "lat": 52.2031074, "lng": 5.3742364, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterspringstaart 18, Amersfoort", "lat": 52.2032157, "lng": 5.3742804, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Waterspringstaart 19, Amersfoort", "lat": 52.2032734, "lng": 5.3742864, "expected_has_charger": None},  # 193m², 1vbo
    {"adres": "Waterspringstaart 20, Amersfoort", "lat": 52.2033792, "lng": 5.3742924, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterspringstaart 21, Amersfoort", "lat": 52.2034209, "lng": 5.3743044, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterspringstaart 22, Amersfoort", "lat": 52.2035316, "lng": 5.3743484, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Waterspringstaart 23, Amersfoort", "lat": 52.2035746, "lng": 5.3743584, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Waterspringstaart 24, Amersfoort", "lat": 52.2036956, "lng": 5.3743512, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Waterspringstaart 25, Amersfoort", "lat": 52.2037332, "lng": 5.3743964, "expected_has_charger": None},  # 188m², 1vbo
    {"adres": "Waterspringstaart 26, Amersfoort", "lat": 52.2038381, "lng": 5.3743767, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Waterspringstaart 27, Amersfoort", "lat": 52.2039016, "lng": 5.3744283, "expected_has_charger": None},  # 170m², 1vbo
    {"adres": "Watertor 1, Amersfoort", "lat": 52.2028776, "lng": 5.3730168, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watertor 2, Amersfoort", "lat": 52.2031040, "lng": 5.3731507, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Watertor 3, Amersfoort", "lat": 52.2028982, "lng": 5.3729431, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watertor 4, Amersfoort", "lat": 52.2031164, "lng": 5.3730861, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 5, Amersfoort", "lat": 52.2029173, "lng": 5.3728717, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Watertor 6, Amersfoort", "lat": 52.2031356, "lng": 5.3730123, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 7, Amersfoort", "lat": 52.2029379, "lng": 5.3728158, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Watertor 8, Amersfoort", "lat": 52.2031479, "lng": 5.3729586, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 9, Amersfoort", "lat": 52.2029571, "lng": 5.3727397, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Watertor 10, Amersfoort", "lat": 52.2031617, "lng": 5.3728738, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 11, Amersfoort", "lat": 52.2029736, "lng": 5.3726638, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Watertor 12, Amersfoort", "lat": 52.2031740, "lng": 5.3728090, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 13, Amersfoort", "lat": 52.2029955, "lng": 5.3726035, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Watertor 14, Amersfoort", "lat": 52.2031891, "lng": 5.3727352, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 15, Amersfoort", "lat": 52.2030202, "lng": 5.3725276, "expected_has_charger": None},  # 134m², 1vbo
    {"adres": "Watertor 16, Amersfoort", "lat": 52.2032069, "lng": 5.3726548, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 17, Amersfoort", "lat": 52.2030422, "lng": 5.3724717, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watertor 18, Amersfoort", "lat": 52.2032206, "lng": 5.3725945, "expected_has_charger": None},  # 120m², 1vbo
    {"adres": "Watertor 19, Amersfoort", "lat": 52.2030614, "lng": 5.3724091, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watertor 20, Amersfoort", "lat": 52.2032343, "lng": 5.3725230, "expected_has_charger": None},  # 81m², 1vbo
    {"adres": "Watertor 21, Amersfoort", "lat": 52.2030848, "lng": 5.3723354, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watertor 22, Amersfoort", "lat": 52.2032481, "lng": 5.3724449, "expected_has_charger": None},  # 91m², 1vbo
    {"adres": "Watertor 23, Amersfoort", "lat": 52.2031039, "lng": 5.3722616, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Watertor 24, Amersfoort", "lat": 52.2032645, "lng": 5.3723934, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Watertor 25, Amersfoort", "lat": 52.2032014, "lng": 5.3720806, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Watertor 26, Amersfoort", "lat": 52.2032864, "lng": 5.3721387, "expected_has_charger": None},  # 143m², 1vbo
    {"adres": "Waterviolier 1, Amersfoort", "lat": 52.2020921, "lng": 5.3757398, "expected_has_charger": None},  # 110m², 1vbo
    {"adres": "Waterviolier 2, Amersfoort", "lat": 52.2022928, "lng": 5.3758744, "expected_has_charger": None},  # 161m², 1vbo
    {"adres": "Waterviolier 3, Amersfoort", "lat": 52.2020952, "lng": 5.3756670, "expected_has_charger": None},  # 114m², 1vbo
    {"adres": "Waterviolier 4, Amersfoort", "lat": 52.2023024, "lng": 5.3757915, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 5, Amersfoort", "lat": 52.2021032, "lng": 5.3755867, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Waterviolier 6, Amersfoort", "lat": 52.2023103, "lng": 5.3757085, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 7, Amersfoort", "lat": 52.2021096, "lng": 5.3755270, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 8, Amersfoort", "lat": 52.2023167, "lng": 5.3756307, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Waterviolier 9, Amersfoort", "lat": 52.2021143, "lng": 5.3754415, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Waterviolier 10, Amersfoort", "lat": 52.2023214, "lng": 5.3755425, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 11, Amersfoort", "lat": 52.2021223, "lng": 5.3753663, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 12, Amersfoort", "lat": 52.2023310, "lng": 5.3754622, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Waterviolier 13, Amersfoort", "lat": 52.2021286, "lng": 5.3752911, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 14, Amersfoort", "lat": 52.2023358, "lng": 5.3753792, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Waterviolier 15, Amersfoort", "lat": 52.2021366, "lng": 5.3752210, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Waterviolier 16, Amersfoort", "lat": 52.2023453, "lng": 5.3752910, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Waterviolier 17, Amersfoort", "lat": 52.2021446, "lng": 5.3751485, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 18, Amersfoort", "lat": 52.2023549, "lng": 5.3752055, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Waterviolier 19, Amersfoort", "lat": 52.2021477, "lng": 5.3750682, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 20, Amersfoort", "lat": 52.2023597, "lng": 5.3751303, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Waterviolier 21, Amersfoort", "lat": 52.2021477, "lng": 5.3749955, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 22, Amersfoort", "lat": 52.2023660, "lng": 5.3750447, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 23, Amersfoort", "lat": 52.2021588, "lng": 5.3749229, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 24, Amersfoort", "lat": 52.2023724, "lng": 5.3749618, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Waterviolier 25, Amersfoort", "lat": 52.2021652, "lng": 5.3748477, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Waterviolier 26, Amersfoort", "lat": 52.2023739, "lng": 5.3748813, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Waterviolier 27, Amersfoort", "lat": 52.2021700, "lng": 5.3747829, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Waterviolier 28, Amersfoort", "lat": 52.2024934, "lng": 5.3746479, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 29, Amersfoort", "lat": 52.2017909, "lng": 5.3746948, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Waterviolier 30, Amersfoort", "lat": 52.2024648, "lng": 5.3746349, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 31, Amersfoort", "lat": 52.2017860, "lng": 5.3747649, "expected_has_charger": None},  # 100m², 1vbo
    {"adres": "Waterviolier 32, Amersfoort", "lat": 52.2023644, "lng": 5.3745416, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 33, Amersfoort", "lat": 52.2017845, "lng": 5.3748374, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Waterviolier 34, Amersfoort", "lat": 52.2023325, "lng": 5.3745184, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 35, Amersfoort", "lat": 52.2017765, "lng": 5.3749153, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Waterviolier 36, Amersfoort", "lat": 52.2021413, "lng": 5.3743396, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 37, Amersfoort", "lat": 52.2017717, "lng": 5.3749904, "expected_has_charger": None},  # 125m², 1vbo
    {"adres": "Waterviolier 38, Amersfoort", "lat": 52.2021142, "lng": 5.3743162, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Waterviolier 39, Amersfoort", "lat": 52.2017606, "lng": 5.3750630, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Waterviolier 40, Amersfoort", "lat": 52.2020123, "lng": 5.3741943, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 41, Amersfoort", "lat": 52.2017542, "lng": 5.3751331, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Waterviolier 42, Amersfoort", "lat": 52.2019835, "lng": 5.3741684, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 43, Amersfoort", "lat": 52.2017526, "lng": 5.3752107, "expected_has_charger": None},  # 113m², 1vbo
    {"adres": "Waterviolier 44, Amersfoort", "lat": 52.2018863, "lng": 5.3740310, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 45, Amersfoort", "lat": 52.2017462, "lng": 5.3752861, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 46, Amersfoort", "lat": 52.2018577, "lng": 5.3740181, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 47, Amersfoort", "lat": 52.2017399, "lng": 5.3753586, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 48, Amersfoort", "lat": 52.2017557, "lng": 5.3739040, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Waterviolier 49, Amersfoort", "lat": 52.2017304, "lng": 5.3754338, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Waterviolier 50, Amersfoort", "lat": 52.2017271, "lng": 5.3738703, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Waterviolier 51, Amersfoort", "lat": 52.2017224, "lng": 5.3755038, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Waterviolier 52, Amersfoort", "lat": 52.2016203, "lng": 5.3738756, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Waterviolier 53, Amersfoort", "lat": 52.2017161, "lng": 5.3755816, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 54, Amersfoort", "lat": 52.2015900, "lng": 5.3738833, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 55, Amersfoort", "lat": 52.2017097, "lng": 5.3756543, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Waterviolier 56, Amersfoort", "lat": 52.2016108, "lng": 5.3741219, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Waterviolier 58, Amersfoort", "lat": 52.2016075, "lng": 5.3742048, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Waterviolier 60, Amersfoort", "lat": 52.2015948, "lng": 5.3742904, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Waterviolier 62, Amersfoort", "lat": 52.2015900, "lng": 5.3743707, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterviolier 64, Amersfoort", "lat": 52.2015821, "lng": 5.3744589, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterviolier 66, Amersfoort", "lat": 52.2015789, "lng": 5.3745367, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterviolier 68, Amersfoort", "lat": 52.2015725, "lng": 5.3746223, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 70, Amersfoort", "lat": 52.2015678, "lng": 5.3747026, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 72, Amersfoort", "lat": 52.2015614, "lng": 5.3747908, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Waterviolier 74, Amersfoort", "lat": 52.2015471, "lng": 5.3748711, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 76, Amersfoort", "lat": 52.2015439, "lng": 5.3749463, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 78, Amersfoort", "lat": 52.2015360, "lng": 5.3750319, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Waterviolier 80, Amersfoort", "lat": 52.2015296, "lng": 5.3751175, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 82, Amersfoort", "lat": 52.2015233, "lng": 5.3751902, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 84, Amersfoort", "lat": 52.2015169, "lng": 5.3752758, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 86, Amersfoort", "lat": 52.2015089, "lng": 5.3753613, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Waterviolier 88, Amersfoort", "lat": 52.2015010, "lng": 5.3754416, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Waterviolier 90, Amersfoort", "lat": 52.2014930, "lng": 5.3755299, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Waterviolier 92, Amersfoort", "lat": 52.2014850, "lng": 5.3756128, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Waterviolier 94, Amersfoort", "lat": 52.2014803, "lng": 5.3757061, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Watervlo 2, Amersfoort", "lat": 52.2025055, "lng": 5.3726104, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 4, Amersfoort", "lat": 52.2025357, "lng": 5.3725545, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 6, Amersfoort", "lat": 52.2025659, "lng": 5.3725075, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 8, Amersfoort", "lat": 52.2025988, "lng": 5.3724427, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 10, Amersfoort", "lat": 52.2026290, "lng": 5.3723870, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 12, Amersfoort", "lat": 52.2026592, "lng": 5.3723311, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 14, Amersfoort", "lat": 52.2026894, "lng": 5.3722774, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 16, Amersfoort", "lat": 52.2027237, "lng": 5.3722239, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 18, Amersfoort", "lat": 52.2027552, "lng": 5.3721634, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 20, Amersfoort", "lat": 52.2027841, "lng": 5.3721121, "expected_has_charger": None},  # 90m², 1vbo
    {"adres": "Watervlo 22, Amersfoort", "lat": 52.2028088, "lng": 5.3720562, "expected_has_charger": None},  # 136m², 1vbo
    {"adres": "Watervlo 24, Amersfoort", "lat": 52.2028403, "lng": 5.3720004, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Watervlo 26, Amersfoort", "lat": 52.2029213, "lng": 5.3717836, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Wildemanskruid 2, Amersfoort", "lat": 52.2037401, "lng": 5.3846665, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "Wildemanskruid 4, Amersfoort", "lat": 52.2037942, "lng": 5.3846482, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 6, Amersfoort", "lat": 52.2038459, "lng": 5.3846592, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 8, Amersfoort", "lat": 52.2038933, "lng": 5.3846849, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 10, Amersfoort", "lat": 52.2039316, "lng": 5.3847363, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 12, Amersfoort", "lat": 52.2039609, "lng": 5.3848132, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 14, Amersfoort", "lat": 52.2039721, "lng": 5.3848903, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 16, Amersfoort", "lat": 52.2039721, "lng": 5.3849673, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 18, Amersfoort", "lat": 52.2039654, "lng": 5.3850553, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 20, Amersfoort", "lat": 52.2039338, "lng": 5.3851359, "expected_has_charger": None},  # 129m², 1vbo
    {"adres": "Wildemanskruid 22, Amersfoort", "lat": 52.2038888, "lng": 5.3852459, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Wildemanskruid 24, Amersfoort", "lat": 52.2038573, "lng": 5.3853157, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Wildemanskruid 26, Amersfoort", "lat": 52.2038211, "lng": 5.3853963, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Wildemanskruid 28, Amersfoort", "lat": 52.2037896, "lng": 5.3854771, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Wildemanskruid 30, Amersfoort", "lat": 52.2037558, "lng": 5.3855651, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Wildemanskruid 32, Amersfoort", "lat": 52.2037242, "lng": 5.3856421, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Wildemanskruid 34, Amersfoort", "lat": 52.2036882, "lng": 5.3857154, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Wildemanskruid 36, Amersfoort", "lat": 52.2036567, "lng": 5.3858035, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Wildemanskruid 38, Amersfoort", "lat": 52.2036229, "lng": 5.3858842, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Wildemanskruid 40, Amersfoort", "lat": 52.2035913, "lng": 5.3859648, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Wildemanskruid 42, Amersfoort", "lat": 52.2035598, "lng": 5.3860382, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Wildemanskruid 44, Amersfoort", "lat": 52.2035282, "lng": 5.3861409, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Wildemanskruid 46, Amersfoort", "lat": 52.2034787, "lng": 5.3862509, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Wildemanskruid 48, Amersfoort", "lat": 52.2034358, "lng": 5.3863315, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Wildemanskruid 50, Amersfoort", "lat": 52.2034043, "lng": 5.3864086, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Wildemanskruid 52, Amersfoort", "lat": 52.2033705, "lng": 5.3864929, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Wildemanskruid 54, Amersfoort", "lat": 52.2033389, "lng": 5.3865773, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Wildemanskruid 56, Amersfoort", "lat": 52.2033074, "lng": 5.3866617, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Wildemanskruid 58, Amersfoort", "lat": 52.2032646, "lng": 5.3867386, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Wildemanskruid 60, Amersfoort", "lat": 52.2032331, "lng": 5.3868157, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Wildemanskruid 62, Amersfoort", "lat": 52.2032038, "lng": 5.3868963, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Wildemanskruid 64, Amersfoort", "lat": 52.2031722, "lng": 5.3869734, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Wildemanskruid 66, Amersfoort", "lat": 52.2031339, "lng": 5.3870577, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Wildemanskruid 68, Amersfoort", "lat": 52.2031024, "lng": 5.3871494, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Wildemanskruid 70, Amersfoort", "lat": 52.2030550, "lng": 5.3872485, "expected_has_charger": None},  # 124m², 1vbo
    {"adres": "Wildemanskruid 72, Amersfoort", "lat": 52.2030235, "lng": 5.3873181, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 74, Amersfoort", "lat": 52.2029807, "lng": 5.3873658, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 76, Amersfoort", "lat": 52.2029357, "lng": 5.3873805, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 78, Amersfoort", "lat": 52.2028793, "lng": 5.3873915, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 80, Amersfoort", "lat": 52.2028297, "lng": 5.3873731, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 82, Amersfoort", "lat": 52.2027847, "lng": 5.3873365, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 84, Amersfoort", "lat": 52.2027531, "lng": 5.3872742, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 86, Amersfoort", "lat": 52.2027283, "lng": 5.3872008, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Wildemanskruid 88, Amersfoort", "lat": 52.2027193, "lng": 5.3871202, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Winstongaarde 1, Amersfoort", "lat": 52.1962456, "lng": 5.3750459, "expected_has_charger": None},  # 99m², 1vbo
    {"adres": "Winstongaarde 2, Amersfoort", "lat": 52.1960247, "lng": 5.3746113, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 3, Amersfoort", "lat": 52.1962414, "lng": 5.3751280, "expected_has_charger": None},  # 128m², 1vbo
    {"adres": "Winstongaarde 4, Amersfoort", "lat": 52.1960153, "lng": 5.3746901, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Winstongaarde 5, Amersfoort", "lat": 52.1962361, "lng": 5.3751999, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Winstongaarde 6, Amersfoort", "lat": 52.1960027, "lng": 5.3747722, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 7, Amersfoort", "lat": 52.1962319, "lng": 5.3752786, "expected_has_charger": None},  # 112m², 1vbo
    {"adres": "Winstongaarde 8, Amersfoort", "lat": 52.1959858, "lng": 5.3749535, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 9, Amersfoort", "lat": 52.1962256, "lng": 5.3753607, "expected_has_charger": None},  # 121m², 1vbo
    {"adres": "Winstongaarde 10, Amersfoort", "lat": 52.1959775, "lng": 5.3750460, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Winstongaarde 11, Amersfoort", "lat": 52.1962214, "lng": 5.3754462, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Winstongaarde 12, Amersfoort", "lat": 52.1959690, "lng": 5.3752238, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 13, Amersfoort", "lat": 52.1962193, "lng": 5.3755249, "expected_has_charger": None},  # 122m², 1vbo
    {"adres": "Winstongaarde 14, Amersfoort", "lat": 52.1959607, "lng": 5.3753060, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 15, Amersfoort", "lat": 52.1962152, "lng": 5.3756002, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Winstongaarde 16, Amersfoort", "lat": 52.1959502, "lng": 5.3754943, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 17, Amersfoort", "lat": 52.1962046, "lng": 5.3756824, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Winstongaarde 18, Amersfoort", "lat": 52.1959417, "lng": 5.3755798, "expected_has_charger": None},  # 184m², 1vbo
    {"adres": "Winstongaarde 19, Amersfoort", "lat": 52.1962046, "lng": 5.3757679, "expected_has_charger": None},  # 102m², 1vbo
    {"adres": "Winstongaarde 20, Amersfoort", "lat": 52.1959292, "lng": 5.3757714, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 21, Amersfoort", "lat": 52.1961984, "lng": 5.3758534, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Winstongaarde 22, Amersfoort", "lat": 52.1959355, "lng": 5.3758501, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 23, Amersfoort", "lat": 52.1961962, "lng": 5.3759219, "expected_has_charger": None},  # 118m², 1vbo
    {"adres": "Winstongaarde 24, Amersfoort", "lat": 52.1959334, "lng": 5.3760281, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 25, Amersfoort", "lat": 52.1961942, "lng": 5.3760074, "expected_has_charger": None},  # 115m², 1vbo
    {"adres": "Winstongaarde 26, Amersfoort", "lat": 52.1959334, "lng": 5.3761171, "expected_has_charger": None},  # 180m², 1vbo
    {"adres": "Winstongaarde 27, Amersfoort", "lat": 52.1961920, "lng": 5.3760896, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Winstongaarde 28, Amersfoort", "lat": 52.1959229, "lng": 5.3762060, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Winstongaarde 29, Amersfoort", "lat": 52.1961942, "lng": 5.3761717, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Winstongaarde 31, Amersfoort", "lat": 52.1965117, "lng": 5.3761647, "expected_has_charger": None},  # 88m², 1vbo
    {"adres": "Zalm 1, Amersfoort", "lat": 52.2029345, "lng": 5.3685565, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Zalm 3, Amersfoort", "lat": 52.2028920, "lng": 5.3685334, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 5, Amersfoort", "lat": 52.2028432, "lng": 5.3685027, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 7, Amersfoort", "lat": 52.2027990, "lng": 5.3684822, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 9, Amersfoort", "lat": 52.2027456, "lng": 5.3685027, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 11, Amersfoort", "lat": 52.2026991, "lng": 5.3684400, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 13, Amersfoort", "lat": 52.2026534, "lng": 5.3684258, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 15, Amersfoort", "lat": 52.2026054, "lng": 5.3684040, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Zalm 17, Amersfoort", "lat": 52.2024203, "lng": 5.3683145, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Zalm 19, Amersfoort", "lat": 52.2023849, "lng": 5.3682620, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 21, Amersfoort", "lat": 52.2023455, "lng": 5.3682223, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 23, Amersfoort", "lat": 52.2023030, "lng": 5.3681801, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 25, Amersfoort", "lat": 52.2022487, "lng": 5.3681750, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 27, Amersfoort", "lat": 52.2022181, "lng": 5.3681007, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 29, Amersfoort", "lat": 52.2021794, "lng": 5.3680558, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 31, Amersfoort", "lat": 52.2021425, "lng": 5.3680097, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Zalm 33, Amersfoort", "lat": 52.2019322, "lng": 5.3679162, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Zalm 35, Amersfoort", "lat": 52.2018945, "lng": 5.3678714, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 37, Amersfoort", "lat": 52.2018559, "lng": 5.3678163, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 39, Amersfoort", "lat": 52.2018173, "lng": 5.3677651, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 41, Amersfoort", "lat": 52.2017795, "lng": 5.3677140, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 43, Amersfoort", "lat": 52.2017260, "lng": 5.3677011, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 45, Amersfoort", "lat": 52.2017039, "lng": 5.3676217, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 47, Amersfoort", "lat": 52.2016670, "lng": 5.3675730, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 49, Amersfoort", "lat": 52.2016291, "lng": 5.3675192, "expected_has_charger": None},  # 176m², 1vbo
    {"adres": "Zalm 51, Amersfoort", "lat": 52.2015874, "lng": 5.3674642, "expected_has_charger": None},  # 200m², 1vbo
    {"adres": "Zeepkruid 2, Amersfoort", "lat": 52.2035733, "lng": 5.3848242, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Zeepkruid 4, Amersfoort", "lat": 52.2035215, "lng": 5.3851873, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Zeepkruid 6, Amersfoort", "lat": 52.2034674, "lng": 5.3852937, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Zeepkruid 8, Amersfoort", "lat": 52.2033908, "lng": 5.3853890, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Zeepkruid 10, Amersfoort", "lat": 52.2033096, "lng": 5.3854148, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 12, Amersfoort", "lat": 52.2032241, "lng": 5.3854404, "expected_has_charger": None},  # 150m², 1vbo
    {"adres": "Zeepkruid 14, Amersfoort", "lat": 52.2031474, "lng": 5.3854844, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 16, Amersfoort", "lat": 52.2030731, "lng": 5.3855027, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 18, Amersfoort", "lat": 52.2030010, "lng": 5.3855394, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 20, Amersfoort", "lat": 52.2029401, "lng": 5.3856752, "expected_has_charger": None},  # 145m², 1vbo
    {"adres": "Zeepkruid 22, Amersfoort", "lat": 52.2029424, "lng": 5.3857852, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 24, Amersfoort", "lat": 52.2029604, "lng": 5.3859062, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 26, Amersfoort", "lat": 52.2029739, "lng": 5.3860492, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Zeepkruid 28, Amersfoort", "lat": 52.2029897, "lng": 5.3861775, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 30, Amersfoort", "lat": 52.2030055, "lng": 5.3863169, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Zeepkruid 32, Amersfoort", "lat": 52.2029852, "lng": 5.3864563, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Zeepkruid 34, Amersfoort", "lat": 52.2029424, "lng": 5.3865736, "expected_has_charger": None},  # 147m², 1vbo
    {"adres": "Zeepkruid 36, Amersfoort", "lat": 52.2027351, "lng": 5.3868084, "expected_has_charger": None},  # 127m², 1vbo
    {"adres": "Zeepkruid 38, Amersfoort", "lat": 52.2027283, "lng": 5.3867240, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Zeepkruid 40, Amersfoort", "lat": 52.2027193, "lng": 5.3866433, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Zeepkruid 42, Amersfoort", "lat": 52.2027126, "lng": 5.3865700, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Zeepkruid 44, Amersfoort", "lat": 52.2027012, "lng": 5.3864892, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Zeepkruid 46, Amersfoort", "lat": 52.2026900, "lng": 5.3864050, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Zeepkruid 48, Amersfoort", "lat": 52.2026675, "lng": 5.3862473, "expected_has_charger": None},  # 162m², 1vbo
    {"adres": "Zeepkruid 50, Amersfoort", "lat": 52.2026607, "lng": 5.3861629, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Zeepkruid 52, Amersfoort", "lat": 52.2026540, "lng": 5.3860860, "expected_has_charger": None},  # 158m², 1vbo
    {"adres": "Zeepkruid 54, Amersfoort", "lat": 52.2026449, "lng": 5.3860052, "expected_has_charger": None},  # 151m², 1vbo
    {"adres": "Zeepkruid 56, Amersfoort", "lat": 52.2026359, "lng": 5.3859319, "expected_has_charger": None},  # 141m², 1vbo
    {"adres": "Zeepkruid 58, Amersfoort", "lat": 52.2026269, "lng": 5.3858438, "expected_has_charger": None},  # 146m², 1vbo
    {"adres": "Zeepkruid 60, Amersfoort", "lat": 52.2026044, "lng": 5.3856531, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Zeepkruid 62, Amersfoort", "lat": 52.2025954, "lng": 5.3855468, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Zeepkruid 64, Amersfoort", "lat": 52.2026134, "lng": 5.3854037, "expected_has_charger": None},  # 159m², 1vbo
    {"adres": "Zeepkruid 66, Amersfoort", "lat": 52.2026495, "lng": 5.3853158, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Zeldertsedreef 10, Amersfoort", "lat": 52.2011305, "lng": 5.3755479, "expected_has_charger": None},  # 185m², 1vbo
    {"adres": "Zeldertsedreef 12, Amersfoort", "lat": 52.2011295, "lng": 5.3754215, "expected_has_charger": None},  # 210m², 1vbo
    {"adres": "Zeldertsedreef 14, Amersfoort", "lat": 52.2011260, "lng": 5.3752609, "expected_has_charger": None},  # 210m², 1vbo
    {"adres": "Zeldertsedreef 15, Amersfoort", "lat": 52.2004262, "lng": 5.3736034, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Zeldertsedreef 16, Amersfoort", "lat": 52.2011307, "lng": 5.3751428, "expected_has_charger": None},  # 228m², 1vbo
    {"adres": "Zeldertsedreef 17, Amersfoort", "lat": 52.2003646, "lng": 5.3736315, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Zeldertsedreef 18, Amersfoort", "lat": 52.2011533, "lng": 5.3749532, "expected_has_charger": None},  # 228m², 1vbo
    {"adres": "Zeldertsedreef 19, Amersfoort", "lat": 52.2002069, "lng": 5.3735268, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Zeldertsedreef 20, Amersfoort", "lat": 52.2011770, "lng": 5.3748100, "expected_has_charger": None},  # 229m², 1vbo
    {"adres": "Zeldertsedreef 21, Amersfoort", "lat": 52.2002586, "lng": 5.3733681, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Zeldertsedreef 22, Amersfoort", "lat": 52.2011925, "lng": 5.3746861, "expected_has_charger": None},  # 228m², 1vbo
    {"adres": "Zeldertsedreef 23, Amersfoort", "lat": 52.2003301, "lng": 5.3733727, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Zeldertsedreef 24, Amersfoort", "lat": 52.2011996, "lng": 5.3745294, "expected_has_charger": None},  # 223m², 1vbo
    {"adres": "Zeldertsedreef 25, Amersfoort", "lat": 52.2004247, "lng": 5.3733704, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Zeldertsedreef 26, Amersfoort", "lat": 52.2011853, "lng": 5.3743804, "expected_has_charger": None},  # 228m², 1vbo
    {"adres": "Zeldertsedreef 27, Amersfoort", "lat": 52.2004631, "lng": 5.3729939, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Zeldertsedreef 28, Amersfoort", "lat": 52.2011461, "lng": 5.3742585, "expected_has_charger": None},  # 230m², 1vbo
    {"adres": "Zeldertsedreef 29, Amersfoort", "lat": 52.2004179, "lng": 5.3730196, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Zeldertsedreef 31, Amersfoort", "lat": 52.2002068, "lng": 5.3729577, "expected_has_charger": None},  # 160m², 1vbo
    {"adres": "Zeldertsedreef 33, Amersfoort", "lat": 52.2002470, "lng": 5.3727598, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Zeldertsedreef 35, Amersfoort", "lat": 52.2003215, "lng": 5.3727340, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Zeldertsedreef 37, Amersfoort", "lat": 52.2004103, "lng": 5.3727105, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Zeldertsedreef 39, Amersfoort", "lat": 52.2004130, "lng": 5.3724057, "expected_has_charger": None},  # 148m², 1vbo
    {"adres": "Zeldertsedreef 41, Amersfoort", "lat": 52.2003548, "lng": 5.3724160, "expected_has_charger": None},  # 149m², 1vbo
    {"adres": "Zeldertsedreef 43, Amersfoort", "lat": 52.2001595, "lng": 5.3724704, "expected_has_charger": None},  # 182m², 1vbo
    {"adres": "Zeldertsedreef 45, Amersfoort", "lat": 52.2001710, "lng": 5.3722415, "expected_has_charger": None},  # 156m², 1vbo
    {"adres": "Zeldertsedreef 47, Amersfoort", "lat": 52.2002498, "lng": 5.3721953, "expected_has_charger": None},  # 164m², 1vbo
    {"adres": "Zeldertsedreef 49, Amersfoort", "lat": 52.2003085, "lng": 5.3721602, "expected_has_charger": None},  # 178m², 1vbo
    {"adres": "Zeldertsedreef 51, Amersfoort", "lat": 52.2001466, "lng": 5.3718552, "expected_has_charger": None},  # 496m², 1vbo
    {"adres": "Zeldertsedreef 53, Amersfoort", "lat": 52.2001800, "lng": 5.3714111, "expected_has_charger": None},  # 431m², 1vbo
    {"adres": "Zoete Aagtgaarde 2, Amersfoort", "lat": 52.1972952, "lng": 5.3693719, "expected_has_charger": None},  # 140m², 1vbo
    {"adres": "Zoete Aagtgaarde 4, Amersfoort", "lat": 52.1973394, "lng": 5.3693548, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Zoete Aagtgaarde 6, Amersfoort", "lat": 52.1973877, "lng": 5.3693274, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Zoete Aagtgaarde 8, Amersfoort", "lat": 52.1974361, "lng": 5.3693136, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Zoete Aagtgaarde 10, Amersfoort", "lat": 52.1974802, "lng": 5.3692896, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Zoete Aagtgaarde 12, Amersfoort", "lat": 52.1975223, "lng": 5.3692691, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Zoete Aagtgaarde 14, Amersfoort", "lat": 52.1975706, "lng": 5.3692451, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Zoete Aagtgaarde 16, Amersfoort", "lat": 52.1976169, "lng": 5.3692178, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Zoete Aagtgaarde 18, Amersfoort", "lat": 52.1976695, "lng": 5.3692006, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Zoete Aagtgaarde 20, Amersfoort", "lat": 52.1977116, "lng": 5.3691801, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Zoete Aagtgaarde 22, Amersfoort", "lat": 52.1977641, "lng": 5.3691528, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Zoete Aagtgaarde 24, Amersfoort", "lat": 52.1978040, "lng": 5.3691321, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Zoete Aagtgaarde 26, Amersfoort", "lat": 52.1978524, "lng": 5.3691116, "expected_has_charger": None},  # 98m², 1vbo
    {"adres": "Zoete Aagtgaarde 28, Amersfoort", "lat": 52.1978987, "lng": 5.3690910, "expected_has_charger": None},  # 109m², 1vbo
    {"adres": "Zoete Aagtgaarde 30, Amersfoort", "lat": 52.1979450, "lng": 5.3690705, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Zoete Aagtgaarde 32, Amersfoort", "lat": 52.1979912, "lng": 5.3690533, "expected_has_charger": None},  # 130m², 1vbo
    {"adres": "Zoete Campagnergaarde 1, Amersfoort", "lat": 52.1968179, "lng": 5.3700291, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Campagnergaarde 2, Amersfoort", "lat": 52.1971797, "lng": 5.3697654, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Campagnergaarde 3, Amersfoort", "lat": 52.1967717, "lng": 5.3699538, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Campagnergaarde 4, Amersfoort", "lat": 52.1971649, "lng": 5.3696525, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Campagnergaarde 5, Amersfoort", "lat": 52.1967212, "lng": 5.3698718, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Campagnergaarde 6, Amersfoort", "lat": 52.1971481, "lng": 5.3695362, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Campagnergaarde 7, Amersfoort", "lat": 52.1966665, "lng": 5.3697862, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Campagnergaarde 8, Amersfoort", "lat": 52.1971270, "lng": 5.3694302, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoete Ermgaard 1, Amersfoort", "lat": 52.1976099, "lng": 5.3676448, "expected_has_charger": None},  # 126m², 1vbo
    {"adres": "Zoete Ermgaard 2, Amersfoort", "lat": 52.1974374, "lng": 5.3678296, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 3, Amersfoort", "lat": 52.1976241, "lng": 5.3677256, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "Zoete Ermgaard 4, Amersfoort", "lat": 52.1973900, "lng": 5.3678604, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 5, Amersfoort", "lat": 52.1976383, "lng": 5.3677949, "expected_has_charger": None},  # 116m², 1vbo
    {"adres": "Zoete Ermgaard 6, Amersfoort", "lat": 52.1973286, "lng": 5.3678835, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 7, Amersfoort", "lat": 52.1976526, "lng": 5.3678718, "expected_has_charger": None},  # 105m², 1vbo
    {"adres": "Zoete Ermgaard 8, Amersfoort", "lat": 52.1972789, "lng": 5.3678989, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 9, Amersfoort", "lat": 52.1976668, "lng": 5.3679449, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "Zoete Ermgaard 10, Amersfoort", "lat": 52.1972198, "lng": 5.3679260, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 11, Amersfoort", "lat": 52.1976833, "lng": 5.3680258, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "Zoete Ermgaard 12, Amersfoort", "lat": 52.1971630, "lng": 5.3679452, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Zoete Ermgaard 13, Amersfoort", "lat": 52.1976975, "lng": 5.3681028, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Zoete Ermgaard 14, Amersfoort", "lat": 52.1971111, "lng": 5.3679645, "expected_has_charger": None},  # 123m², 1vbo
    {"adres": "Zoete Ermgaard 15, Amersfoort", "lat": 52.1977094, "lng": 5.3681759, "expected_has_charger": None},  # 103m², 1vbo
    {"adres": "Zoete Ermgaard 16, Amersfoort", "lat": 52.1970519, "lng": 5.3679876, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 17, Amersfoort", "lat": 52.1977212, "lng": 5.3682490, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Zoete Ermgaard 19, Amersfoort", "lat": 52.1977331, "lng": 5.3683259, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "Zoete Ermgaard 21, Amersfoort", "lat": 52.1977473, "lng": 5.3684029, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "Zoete Ermgaard 23, Amersfoort", "lat": 52.1977591, "lng": 5.3684837, "expected_has_charger": None},  # 117m², 1vbo
    {"adres": "Zoete Ermgaard 25, Amersfoort", "lat": 52.1977733, "lng": 5.3685607, "expected_has_charger": None},  # 108m², 1vbo
    {"adres": "Zoete Ermgaard 27, Amersfoort", "lat": 52.1977852, "lng": 5.3686376, "expected_has_charger": None},  # 106m², 1vbo
    {"adres": "Zoete Ermgaard 29, Amersfoort", "lat": 52.1978017, "lng": 5.3687107, "expected_has_charger": None},  # 111m², 1vbo
    {"adres": "Zoete Ermgaard 31, Amersfoort", "lat": 52.1978183, "lng": 5.3687878, "expected_has_charger": None},  # 101m², 1vbo
    {"adres": "Zoete Ermgaard 33, Amersfoort", "lat": 52.1973571, "lng": 5.3689919, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 35, Amersfoort", "lat": 52.1973406, "lng": 5.3688918, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 37, Amersfoort", "lat": 52.1973335, "lng": 5.3688072, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 39, Amersfoort", "lat": 52.1973169, "lng": 5.3687187, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 41, Amersfoort", "lat": 52.1973050, "lng": 5.3686418, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 43, Amersfoort", "lat": 52.1972837, "lng": 5.3685417, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 45, Amersfoort", "lat": 52.1972695, "lng": 5.3684570, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoete Ermgaard 47, Amersfoort", "lat": 52.1972554, "lng": 5.3683646, "expected_has_charger": None},  # 166m², 1vbo
    {"adres": "Zoetegaarde 1, Amersfoort", "lat": 52.1966713, "lng": 5.3688499, "expected_has_charger": None},  # 189m², 1vbo
    {"adres": "Zoetegaarde 2, Amersfoort", "lat": 52.1970734, "lng": 5.3691305, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 3, Amersfoort", "lat": 52.1966783, "lng": 5.3685380, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Zoetegaarde 4, Amersfoort", "lat": 52.1970450, "lng": 5.3689998, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 5, Amersfoort", "lat": 52.1966452, "lng": 5.3683610, "expected_has_charger": None},  # 152m², 1vbo
    {"adres": "Zoetegaarde 6, Amersfoort", "lat": 52.1970284, "lng": 5.3688920, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Zoetegaarde 7, Amersfoort", "lat": 52.1966073, "lng": 5.3681841, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Zoetegaarde 8, Amersfoort", "lat": 52.1970095, "lng": 5.3687957, "expected_has_charger": None},  # 157m², 1vbo
    {"adres": "Zoetegaarde 9, Amersfoort", "lat": 52.1965529, "lng": 5.3680070, "expected_has_charger": None},  # 218m², 1vbo
    {"adres": "Zoetegaarde 10, Amersfoort", "lat": 52.1969906, "lng": 5.3686919, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 11, Amersfoort", "lat": 52.1964914, "lng": 5.3678492, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Zoetegaarde 12, Amersfoort", "lat": 52.1969763, "lng": 5.3685803, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 13, Amersfoort", "lat": 52.1964204, "lng": 5.3676838, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Zoetegaarde 14, Amersfoort", "lat": 52.1969598, "lng": 5.3684763, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 15, Amersfoort", "lat": 52.1963140, "lng": 5.3675838, "expected_has_charger": None},  # 163m², 1vbo
    {"adres": "Zoetegaarde 16, Amersfoort", "lat": 52.1968935, "lng": 5.3681647, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 18, Amersfoort", "lat": 52.1968769, "lng": 5.3680493, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 20, Amersfoort", "lat": 52.1968627, "lng": 5.3679453, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 22, Amersfoort", "lat": 52.1968462, "lng": 5.3678375, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 24, Amersfoort", "lat": 52.1968272, "lng": 5.3677259, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 26, Amersfoort", "lat": 52.1968083, "lng": 5.3676259, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 28, Amersfoort", "lat": 52.1967845, "lng": 5.3675182, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 30, Amersfoort", "lat": 52.1970021, "lng": 5.3674180, "expected_has_charger": None},  # 119m², 1vbo
    {"adres": "Zoetegaarde 32, Amersfoort", "lat": 52.1970471, "lng": 5.3673988, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Zoetegaarde 34, Amersfoort", "lat": 52.1971393, "lng": 5.3673679, "expected_has_charger": None},  # 142m², 1vbo
    {"adres": "Zoetegaarde 36, Amersfoort", "lat": 52.1971771, "lng": 5.3673447, "expected_has_charger": None},  # 137m², 1vbo
    {"adres": "Zoetegaarde 38, Amersfoort", "lat": 52.1972693, "lng": 5.3673217, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Zoetegaarde 40, Amersfoort", "lat": 52.1973072, "lng": 5.3673102, "expected_has_charger": None},  # 139m², 1vbo
    {"adres": "Zoetegaarde 42, Amersfoort", "lat": 52.1975413, "lng": 5.3672330, "expected_has_charger": None},  # 203m², 1vbo
    {"adres": "Zoetegaarde 44, Amersfoort", "lat": 52.1976785, "lng": 5.3671753, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Zoetegaarde 46, Amersfoort", "lat": 52.1978417, "lng": 5.3672406, "expected_has_charger": None},  # 210m², 1vbo
    {"adres": "Zoetegaarde 48, Amersfoort", "lat": 52.1979481, "lng": 5.3674446, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Zoetegaarde 50, Amersfoort", "lat": 52.1979813, "lng": 5.3676523, "expected_has_charger": None},  # 168m², 1vbo
    {"adres": "Zoetegaarde 52, Amersfoort", "lat": 52.1979954, "lng": 5.3677447, "expected_has_charger": None},  # 173m², 1vbo
    {"adres": "Zoetegaarde 54, Amersfoort", "lat": 52.1980310, "lng": 5.3679410, "expected_has_charger": None},  # 186m², 1vbo
    {"adres": "Zoetegaarde 56, Amersfoort", "lat": 52.1980499, "lng": 5.3680333, "expected_has_charger": None},  # 174m², 1vbo
    {"adres": "Zoetegaarde 58, Amersfoort", "lat": 52.1980783, "lng": 5.3682411, "expected_has_charger": None},  # 177m², 1vbo
    {"adres": "Zoetegaarde 60, Amersfoort", "lat": 52.1980949, "lng": 5.3683182, "expected_has_charger": None},  # 179m², 1vbo
    {"adres": "Zoetegaarde 62, Amersfoort", "lat": 52.1981328, "lng": 5.3685336, "expected_has_charger": None},  # 165m², 1vbo
    {"adres": "Zoetegaarde 64, Amersfoort", "lat": 52.1981446, "lng": 5.3686145, "expected_has_charger": None},  # 144m², 1vbo
    {"adres": "Zoetegaarde 66, Amersfoort", "lat": 52.1982109, "lng": 5.3689646, "expected_has_charger": None},  # 153m², 1vbo
    {"adres": "Zoetegaarde 68, Amersfoort", "lat": 52.1982251, "lng": 5.3690378, "expected_has_charger": None},  # 171m², 1vbo
    {"adres": "Zoetegaarde 70, Amersfoort", "lat": 52.1982605, "lng": 5.3692571, "expected_has_charger": None},  # 191m², 1vbo
    {"adres": "Zoetegaarde 72, Amersfoort", "lat": 52.1982346, "lng": 5.3694803, "expected_has_charger": None},  # 203m², 1vbo
]

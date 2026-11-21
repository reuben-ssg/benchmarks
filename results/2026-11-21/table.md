
## 10 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 35.0 | 34.1 | 46 | 33 |  |
| reuben, bare | 7.2 | 6.7 | 25 | 15 | 17,572 |
| reuben, bare, footnote back-links off | 7.0 | 6.6 | 23 | 15 | 16,972 |
| reuben, bare + checks | 7.4 | 7.0 | 27 | 15 | 17,572 |
| hugo, bare, highlighting on | 34.7 | 33.4 | 57 | 70 | 25,826 |
| hugo, bare, highlighting off | 33.0 | 32.4 | 51 | 68 | 19,006 |
| zola, bare, highlighting on | 36.4 | 35.2 | 53 | 67 | 22,410 |
| zola, bare, highlighting off | 14.8 | 14.5 | 24 | 28 | 17,190 |

## 50 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 55.2 | 43.9 | 88 | 36 |  |
| reuben, bare | 11.8 | 10.6 | 56 | 16 | 88,954 |
| reuben, bare, footnote back-links off | 11.1 | 10.3 | 56 | 16 | 85,954 |
| reuben, bare + checks | 12.9 | 11.2 | 64 | 16 | 88,954 |
| hugo, bare, highlighting on | 41.9 | 40.0 | 94 | 79 | 130,032 |
| hugo, bare, highlighting off | 38.0 | 37.1 | 74 | 71 | 95,932 |
| zola, bare, highlighting on | 44.8 | 42.9 | 85 | 69 | 112,872 |
| zola, bare, highlighting off | 18.4 | 17.3 | 46 | 30 | 86,772 |

## 1000 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 219.2 | 209.0 | 546 | 57 |  |
| reuben, bare | 73.7 | 71.2 | 547 | 28 | 1,794,109 |
| reuben, bare, footnote back-links off | 96.7 | 71.6 | 547 | 28 | 1,734,109 |
| reuben, bare + checks | 104.3 | 100.1 | 556 | 30 | 1,794,109 |
| hugo, bare, highlighting on | 154.5 | 151.2 | 806 | 183 | 2,614,757 |
| hugo, bare, highlighting off | 140.3 | 125.9 | 584 | 149 | 1,932,757 |
| zola, bare, highlighting on | 201.1 | 182.1 | 693 | 89 | 2,271,177 |
| zola, bare, highlighting off | 88.0 | 81.3 | 502 | 52 | 1,749,177 |

## 10000 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 1707.1 | 1694.6 | 4415 | 237 |  |
| reuben, bare | 691.4 | 656.8 | 4652 | 133 | 18,042,709 |
| reuben, bare, footnote back-links off | 662.1 | 643.1 | 4690 | 134 | 17,442,709 |
| reuben, bare + checks | 993.6 | 964.3 | 5079 | 148 | 18,042,709 |
| hugo, bare, highlighting on | 1383.5 | 1345.1 | 8265 | 972 | 26,248,757 |
| hugo, bare, highlighting off | 1088.4 | 1055.7 | 5602 | 804 | 19,428,757 |
| zola, bare, highlighting on | 1606.6 | 1584.8 | 5943 | 292 | 22,812,777 |
| zola, bare, highlighting off | 744.7 | 733.9 | 4621 | 253 | 17,592,777 |

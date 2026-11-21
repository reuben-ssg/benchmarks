
## 10 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 48.0 | 35.1 | 50 | 33 |  |
| reuben, bare | 7.6 | 6.9 | 27 | 15 | 17,572 |
| reuben, bare, footnote back-links off | 7.3 | 6.7 | 25 | 15 | 16,972 |
| reuben, bare + checks | 8.7 | 7.9 | 27 | 15 | 17,572 |
| hugo, bare, highlighting on | 37.7 | 35.8 | 62 | 71 | 25,826 |
| hugo, bare, highlighting off | 34.6 | 33.5 | 53 | 68 | 19,006 |
| zola, bare, highlighting on | 37.5 | 36.4 | 55 | 67 | 22,410 |
| zola, bare, highlighting off | 15.7 | 14.9 | 25 | 28 | 17,190 |

## 50 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 57.4 | 48.6 | 87 | 36 |  |
| reuben, bare | 12.6 | 11.3 | 63 | 16 | 88,954 |
| reuben, bare, footnote back-links off | 12.6 | 11.2 | 58 | 16 | 85,954 |
| reuben, bare + checks | 14.4 | 12.1 | 68 | 16 | 88,954 |
| hugo, bare, highlighting on | 45.5 | 43.0 | 100 | 79 | 130,032 |
| hugo, bare, highlighting off | 41.8 | 39.8 | 79 | 71 | 95,932 |
| zola, bare, highlighting on | 47.3 | 44.5 | 87 | 69 | 112,872 |
| zola, bare, highlighting off | 19.5 | 18.1 | 50 | 30 | 86,772 |

## 1000 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 214.5 | 206.8 | 546 | 56 |  |
| reuben, bare | 77.0 | 72.7 | 541 | 28 | 1,794,109 |
| reuben, bare, footnote back-links off | 77.2 | 72.3 | 539 | 28 | 1,734,109 |
| reuben, bare + checks | 105.3 | 102.4 | 567 | 30 | 1,794,109 |
| hugo, bare, highlighting on | 163.1 | 153.3 | 816 | 182 | 2,614,757 |
| hugo, bare, highlighting off | 134.5 | 129.3 | 552 | 148 | 1,932,757 |
| zola, bare, highlighting on | 197.9 | 193.5 | 679 | 90 | 2,271,177 |
| zola, bare, highlighting off | 87.1 | 81.4 | 477 | 52 | 1,749,177 |

## 10000 pages

| tool | median ms | min ms | user + sys ms | peak RSS MiB | output bytes |
|---|---|---|---|---|---|
| reuben baseline, bare | 1773.4 | 1723.1 | 4490 | 237 |  |
| reuben, bare | 676.9 | 667.9 | 4913 | 134 | 18,042,709 |
| reuben, bare, footnote back-links off | 656.1 | 646.9 | 4969 | 134 | 17,442,709 |
| reuben, bare + checks | 983.2 | 977.4 | 5333 | 147 | 18,042,709 |
| hugo, bare, highlighting on | 1351.1 | 1340.0 | 8397 | 1009 | 26,248,757 |
| hugo, bare, highlighting off | 1076.3 | 1049.9 | 5585 | 822 | 19,428,757 |
| zola, bare, highlighting on | 1635.1 | 1609.0 | 6285 | 291 | 22,812,777 |
| zola, bare, highlighting off | 753.5 | 749.1 | 4749 | 252 | 17,592,777 |

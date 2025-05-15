# 測試範例測試資料用的指令

如果你想要用範例測試資料做測試，你可以使用底下提供的指令。但注意如果你要測試 TaskX，請在 TaskX 的資料夾底下執行你的 script，以確保工作目錄在正確的位置。

## Task1

### sample1-1.out

```
./judge ac.c
```

### sample1-2.out

```
./judge wa.c
```

### sample1-3.out

```
./judge tle.c
```

## Task2

### sample2-1.out

```
./judge -d tests -t 0.1 -c checker.sh code.c
```

## Task3

### sample3-1.out

```
./judge -s subtasks.json code.c
```

## Task4

### sample4-1.out

```
./judge -s subtasks.json ac.c
```

### sample4-2.out

```
./judge -s subtasks.json wa.c
```

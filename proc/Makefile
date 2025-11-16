CC = gcc
CFLAGS = -Wall -O2
TARGET = affichage
SOURCE = affichage.c

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE)
	@echo "✓ Processus compilé: $(TARGET)"

clean:
	rm -f $(TARGET)

run: $(TARGET)
	./$(TARGET) &
	@echo "Processus lancé en arrière-plan"

.PHONY: all clean run

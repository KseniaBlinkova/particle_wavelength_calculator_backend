package main

import (
	"context"
	"database/sql"
	_ "embed"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"particleapp/internal/config"
	"particleapp/internal/filestorage"
)

//go:embed seed.sql
var seedSQL string

func main() {
	media := flag.String("media", "../particle_wavelength_calculator_frontend/public/media", "каталог изображений и видео")
	flag.Parse()
	if err := seed(*media); err != nil {
		log.Fatal(err)
	}
}

func seed(media string) error {
	cfg := config.Load()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	files, err := filestorage.NewMinIO(cfg.MinIO)
	if err != nil {
		return err
	}
	for _, particle := range []string{"electron", "proton", "neutron", "positron"} {
		for _, format := range []struct{ extension, mime string }{{".jpg", "image/jpeg"}, {".mp4", "video/mp4"}} {
			name := particle + format.extension
			if err := upload(ctx, files, filepath.Join(media, name), name, format.mime); err != nil {
				return err
			}
		}
	}

	if err := upload(ctx, files, filepath.Join(media, "..", "DefaultImage.jpg"), "neutrino.jpg", "image/jpeg"); err != nil {
		return err
	}

	db, err := sql.Open("pgx", cfg.DatabaseDSN)
	if err != nil {
		return err
	}
	defer db.Close()
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, seedSQL); err != nil {
		return fmt.Errorf("заполнение PostgreSQL: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	_, err = db.ExecContext(ctx, "ANALYZE particles")
	if err == nil {
		log.Print("Данные готовы: 120 000 тестовых услуг и 5 демонстрационных карточек")
	}
	return err
}

func upload(ctx context.Context, files *filestorage.MinIO, path, name, mime string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return err
	}
	return files.Upload(ctx, "extras/"+name, file, info.Size(), mime)
}

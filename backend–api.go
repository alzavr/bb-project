package main

import (
"database/sql"
"encoding/json"
"fmt"
_ "github.com/lib/pq"
"gopkg.in/yaml.v3"
"log"
"net/http"
"os"
)

type Config struct {
Database struct {
Host string `yaml:"host"`
Port string `yaml:"port"`
User string `yaml:"user"`
Password string `yaml:"password"`
Name string `yaml:"dbname"`
SSLMode string `yaml:"sslmode"`
} `yaml:"database"`
}

func loadConfig(path string) (*Config, error) {
file, err := os.ReadFile(path)
if err != nil {
return &Config{}, err
}
var cfg Config
if err := yaml.Unmarshal(file, &cfg); err != nil {
return &Config{}, err
}
return &cfg, nil
}

func main() {
// Читаем конфиг-файл
configPath := os.Getenv("CONFIG_PATH")
if configPath == "" {
configPath = "/etc/backend-api/config.yaml"
}
cfg, _ := loadConfig(configPath)

// Читаем из окружения, если есть
dbHost := os.Getenv("DB_HOST")
if dbHost == "" {
dbHost = cfg.Database.Host
}
dbPort := os.Getenv("DB_PORT")
if dbPort == "" {
dbPort = cfg.Database.Port
}
dbUser := os.Getenv("DB_USER")
if dbUser == "" {
dbUser = cfg.Database.User
}
dbPassword := os.Getenv("DB_PASSWORD")
if dbPassword == "" {
dbPassword = cfg.Database.Password
}
dbName := os.Getenv("DB_NAME")
if dbName == "" {
dbName = cfg.Database.Name
}
sslMode := os.Getenv("DB_SSLMODE")
if sslMode == "" {
sslMode = cfg.Database.SSLMode
}
if sslMode == "" {
sslMode = "disable"
}

// DSN для PostgreSQL
dsn := fmt.Sprintf(
"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
dbHost, dbPort, dbUser, dbPassword, dbName, sslMode,
)

db, err := sql.Open("postgres", dsn)
if err != nil {
log.Fatalf("Ошибка подключения к БД: %v", err)
}
defer db.Close()

if err := db.Ping(); err != nil {
log.Fatalf("БД недоступна: %v", err)
}

log.Println("Backend API запущен на :8080")

http.HandleFunc("/user", func(w http.ResponseWriter, r *http.Request) {
id := r.URL.Query().Get("id")
row := db.QueryRow("SELECT id, name, age FROM users WHERE id = $1", id)
var u struct {
ID int `json:"id"`
Name string `json:"name"`
Age int `json:"age"`
}
if err := row.Scan(&u.ID, &u.Name, &u.Age); err != nil {
http.Error(w, "not found", http.StatusNotFound)
return
}
json.NewEncoder(w).Encode(u)
})

log.Fatal(http.ListenAndServe(":8080", nil))
}
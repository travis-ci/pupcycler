package pupcycler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	negronilogrus "github.com/meatballhat/negroni-logrus"
	"github.com/sirupsen/logrus"
	"github.com/urfave/negroni"
)

type server struct {
	log    logrus.FieldLogger
	router *mux.Router
}

func (srv *server) Serve(port string) error {
	if !strings.Contains(port, ":") {
		port = fmt.Sprintf(":%s", port)
	}

	if srv.router == nil {
		srv.setupRouter()
	}

	srv.log.WithField("port", port).Info("listening")

	return http.ListenAndServe(port, negroni.New(
		negroni.NewRecovery(),
		negronilogrus.NewMiddleware(),
		negroni.Wrap(srv.router),
	))
}

func (srv *server) setupRouter() {
	srv.router = mux.NewRouter()
	srv.router.HandleFunc(`/`, srv.ohai).Methods("GET", "HEAD")
}

func (srv *server) ohai(w http.ResponseWriter, req *http.Request) {
	jsonRespond(w, http.StatusOK, &jsonMsg{Message: "🐕♻™"})
}

func jsonRespond(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	jsonBytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		logrus.WithField("err", err).Error("failed to marshal data to json")
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, `{"error":"something awful happened, but it's a secret™"}`)
		return
	}
	w.WriteHeader(status)
	fmt.Fprintf(w, string(jsonBytes))
}

type jsonMsg struct {
	Message string `json:"message"`
}

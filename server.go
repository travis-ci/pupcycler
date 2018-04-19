package pupcycler

import (
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	negronilogrus "github.com/meatballhat/negroni-logrus"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"github.com/urfave/negroni"
)

var (
	errUnauthorized  = errors.New("unauthorized")
	errForbidden     = errors.New("forbidden")
	errInvalidServer = errors.New("invalid server")
)

type server struct {
	authTokens []string

	db     store
	log    logrus.FieldLogger
	router *mux.Router
}

func (srv *server) Serve(port string) error {
	if srv.db == nil {
		return errors.Wrap(errInvalidServer, "no data store present")
	}

	if !strings.Contains(port, ":") {
		port = fmt.Sprintf(":%s", port)
	}

	if srv.authTokens == nil {
		return errors.Wrap(errInvalidServer, "no auth tokens present")
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

	srv.router.Handle(`/devices/{id}/state`,
		srv.authd(srv.handleStateUpdate)).Methods("PUT")
}

func (srv *server) authd(f http.HandlerFunc) http.Handler {
	return negroni.New(negroni.HandlerFunc(srv.requireAuth), negroni.Wrap(http.HandlerFunc(f)))
}

func (srv *server) requireAuth(w http.ResponseWriter, req *http.Request, next http.HandlerFunc) {
	authHeader := strings.TrimSpace(req.Header.Get("Authorization"))
	if authHeader == "" {
		w.Header().Set("WWW-Authenticate", "token")
		jsonRespond(w, http.StatusUnauthorized, &jsonErr{Err: errUnauthorized})
		return
	}

	for _, tok := range srv.authTokens {
		if subtle.ConstantTimeCompare([]byte(authHeader), []byte(fmt.Sprintf("token %s", tok))) == 1 {
			next(w, req)
			return
		}
	}

	jsonRespond(w, http.StatusForbidden, &jsonErr{Err: errForbidden})
}

func (srv *server) ohai(w http.ResponseWriter, req *http.Request) {
	jsonRespond(w, http.StatusOK, &jsonMsg{Message: "🐕♻™"})
}

func (srv *server) handleStateUpdate(w http.ResponseWriter, req *http.Request) {
	deviceID := mux.Vars(req)["id"]

	msg := &stateUpdateMessage{}
	err := json.NewDecoder(req.Body).Decode(msg)
	if err != nil {
		jsonRespond(w, http.StatusBadRequest, &jsonErr{
			Err: errors.Wrap(err, "invalid json received"),
		})
		return
	}

	dev, err := srv.db.UpdateDeviceState(deviceID, msg.Cur, msg.New)
	if err != nil {
		jsonRespond(w, http.StatusInternalServerError, &jsonErr{
			Err: errors.Wrap(err, "failed to update device state"),
		})
		return
	}

	jsonRespond(w, http.StatusOK, dev)
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

type jsonErr struct {
	Err error
}

func (je *jsonErr) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf(`{"error":%q}`, je.Err.Error())), nil
}

type jsonMsg struct {
	Message string `json:"message"`
}

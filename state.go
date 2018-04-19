package pupcycler

type stateUpdateMessage struct {
	Cur string `json:"cur"`
	New string `json:"new"`
}

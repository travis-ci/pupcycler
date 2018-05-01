package pupcycler

import "fmt"

type device struct {
	ID    string `json:"id"`
	State string `json:"state"`
}

func (d *device) UpdateState(newState string) error {
	switch d.State {
	case "":
		d.State = newState
		return nil
	default:
		return fmt.Errorf("invalid or unknown state %q", d.State)
	}
}

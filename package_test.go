package pupcycler

import "testing"

func TestNothingReally(t *testing.T) {
	if 1 != 1 {
		t.Fatalf("invalid universe")
	}
}

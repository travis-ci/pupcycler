package pupcycler

import (
	"log"
	"os"

	cli "gopkg.in/urfave/cli.v2"
)

// Main runs the whole thing wheee
func Main() {
	app := &cli.App{}
	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}

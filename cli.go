package pupcycler

import (
	"log"
	"os"

	"github.com/sirupsen/logrus"
	cli "gopkg.in/urfave/cli.v2"
)

// Main runs the whole thing wheee
func Main() {
	app := &cli.App{
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "debug",
				Usage:   "enable debug logging",
				Aliases: []string{"D"},
				EnvVars: []string{"PUPCYCLER_DEBUG", "DEBUG"},
			},
		},
		Commands: []*cli.Command{
			{
				Name:   "serve",
				Action: runServe,
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:    "port",
						Value:   "9983",
						Usage:   "port number or address at which to listen/serve",
						Aliases: []string{"p"},
						EnvVars: []string{"PUPCYCLER_PORT", "PORT"},
					},
				},
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}

func runServe(ctx *cli.Context) error {
	srv := &server{log: setupLogger(ctx.Bool("debug"))}
	return srv.Serve(ctx.String("port"))
}

func setupLogger(debug bool) logrus.FieldLogger {
	log := logrus.New()
	if debug {
		log.SetLevel(logrus.DebugLevel)
	}
	return log
}

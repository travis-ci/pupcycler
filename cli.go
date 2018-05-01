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
			&cli.StringFlag{
				Name:    "redis-url",
				Value:   "redis://localhost:6379/0",
				Usage:   "the `REDIS_URL` used for cruddy fun",
				Aliases: []string{"R"},
				EnvVars: []string{"PUPCYCLER_REDIS_URL", "REDIS_URL"},
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
					&cli.StringSliceFlag{
						Name:    "auth-tokens",
						Usage:   "auth tokens used as tokens for auth",
						Aliases: []string{"T"},
						EnvVars: []string{"PUPCYCLER_AUTH_TOKENS", "AUTH_TOKENS"},
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
	srv := &server{
		authTokens: ctx.StringSlice("auth-tokens"),
		log:        setupLogger(ctx.Bool("debug")),
		db:         setupDbFromCtx(ctx),
	}
	return srv.Serve(ctx.String("port"))
}

func setupLogger(debug bool) logrus.FieldLogger {
	log := logrus.New()
	if debug {
		log.SetLevel(logrus.DebugLevel)
	}
	return log
}

func setupDbFromCtx(ctx *cli.Context) store {
	return &redisStore{
		cg: buildRedisPool(ctx.String("redis-url")),
	}
}

package pupcycler

import (
	"fmt"
	"time"

	"github.com/gomodule/redigo/redis"
)

type redisStore struct {
	cg redisConnGetter
}

type redisConnGetter interface {
	Get() redis.Conn
}

func buildRedisPool(redisURL string) redisConnGetter {
	return &redis.Pool{
		MaxIdle:     3,
		IdleTimeout: time.Minute,
		Dial: func() (redis.Conn, error) {
			return redis.DialURL(redisURL)
		},
		TestOnBorrow: func(c redis.Conn, t time.Time) error {
			if time.Since(t) < time.Minute {
				return nil
			}
			_, err := c.Do("PING")
			return err
		},
	}
}

func (rs *redisStore) UpdateDeviceState(deviceID, curState, newState string) (*device, error) {
	dev, err := rs.getDevice(deviceID)
	if err != nil {
		return nil, err
	}

	if dev.State != curState {
		return nil, fmt.Errorf("mismatched current state=%q actual=%q", curState, dev.State)
	}

	err = dev.UpdateState(newState)
	if err != nil {
		return nil, err
	}

	err = rs.saveDevice(dev)
	return dev, err
}

func (rs *redisStore) getDevice(deviceID string) (*device, error) {
	return nil, nil
}

func (rs *redisStore) saveDevice(dev *device) error {
	return nil
}

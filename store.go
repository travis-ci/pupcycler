package pupcycler

type store interface {
	UpdateDeviceState(string, string, string) (*device, error)
}

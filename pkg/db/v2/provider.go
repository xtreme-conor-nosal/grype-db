package db

import (
	"context"
	"time"
)

// TODO: delete me

type DataProvider interface {
	Age() time.Time
	Update(context.Context) error
	Provide() *Entry
}

package feedredis

import (
	"context"
	"strconv"

	"github.com/redis/go-redis/v9"
)

type Cache struct {
	client *redis.Client
}

func New(options *redis.Options) *Cache {
	return &Cache{client: redis.NewClient(options)}
}

func (c *Cache) Close() error { return c.client.Close() }

// A concurrent request can generate its own sample, but only the first sample
// is committed. Every caller receives the same ordered IDs.
var storeBatch = redis.NewScript(`
if redis.call('EXISTS', KEYS[1]) == 0 then
  for i = 2, #ARGV do
    redis.call('ZADD', KEYS[1], tonumber(ARGV[1]) + i - 2, ARGV[i])
  end
  redis.call('EXPIRE', KEYS[1], 3600)
end
return redis.call('ZRANGE', KEYS[1], 0, -1)
`)

func (c *Cache) Batch(ctx context.Context, key string, firstNumber int, sample func() ([]uint, error)) ([]uint, error) {
	members, err := c.client.ZRange(ctx, key, 0, -1).Result()
	if err != nil {
		return nil, err
	}
	if len(members) == 0 {
		ids, err := sample()
		if err != nil || len(ids) == 0 {
			return ids, err
		}
		args := make([]any, 0, len(ids)+1)
		args = append(args, firstNumber)
		for _, id := range ids {
			args = append(args, strconv.FormatUint(uint64(id), 10))
		}
		members, err = storeBatch.Run(ctx, c.client, []string{key}, args...).StringSlice()
		if err != nil {
			return nil, err
		}
	}
	ids := make([]uint, 0, len(members))
	for _, member := range members {
		id, err := strconv.ParseUint(member, 10, strconv.IntSize)
		if err != nil {
			return nil, err
		}
		ids = append(ids, uint(id))
	}
	return ids, nil
}

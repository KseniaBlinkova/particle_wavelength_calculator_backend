package particle

import (
	"context"
	"fmt"
	"net/http"
	"regexp"
	"strconv"

	"particleapp/internal/apperror"
	"particleapp/internal/auth"
	"particleapp/internal/web"
)

const feedBatchSize = 100

var feedSessionPattern = regexp.MustCompile("^[a-f0-9]{32}$")

type FeedCache interface {
	Batch(ctx context.Context, key string, firstNumber int, sample func() ([]uint, error)) ([]uint, error)
}

type FeedCard struct {
	Number int `json:"number"`
	ParticleResponse
}

type RandomFeedResponse struct {
	Items []FeedCard `json:"items"`
	Batch int        `json:"batch"`
}

func randomFeed(domain Domain) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		session := r.Header.Get("X-Feed-Session")
		batch, err := strconv.ParseInt(r.URL.Query().Get("batch"), 10, 24)
		if !feedSessionPattern.MatchString(session) || err != nil || batch < 1 {
			web.WriteError(w, apperror.Validation("Требуются идентификатор сессии и номер партии"))
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		response, err := domain.RandomFeed(r.Context(), session, int(batch))
		if err != nil {
			web.WriteError(w, err)
			return
		}
		web.WriteJSON(w, http.StatusOK, response)
	}
}

func (u *Usecase) RandomFeed(ctx context.Context, session string, batch int) (RandomFeedResponse, error) {
	viewerID, signedIn := auth.UserID(ctx)
	scope := "guest"
	if signedIn {
		scope = fmt.Sprintf("user:%d", viewerID)
	}
	key := fmt.Sprintf("particle-feed:%s:%s:%d", scope, session, batch)
	firstNumber := (batch-1)*feedBatchSize + 1
	ids, err := u.feedCache.Batch(ctx, key, firstNumber, func() ([]uint, error) {
		return u.repo.RandomPublishedIDs(ctx, feedBatchSize)
	})
	if err != nil {
		return RandomFeedResponse{}, apperror.Internal("Не удалось сформировать ленту")
	}
	response := RandomFeedResponse{Batch: batch, Items: make([]FeedCard, 0, len(ids))}
	if len(ids) == 0 {
		return response, nil
	}
	particles, err := u.repo.PublishedByIDs(ctx, ids)
	if err != nil {
		return RandomFeedResponse{}, apperror.Internal("Не удалось получить карточки ленты")
	}
	items, err := u.responses(ctx, particles)
	if err != nil {
		return RandomFeedResponse{}, err
	}
	byID := make(map[uint]ParticleResponse, len(items))
	for _, item := range items {
		byID[item.ID] = item
	}
	for index, id := range ids {
		if item, ok := byID[id]; ok {
			response.Items = append(response.Items, FeedCard{
				Number:           firstNumber + index,
				ParticleResponse: item,
			})
		}
	}
	return response, nil
}

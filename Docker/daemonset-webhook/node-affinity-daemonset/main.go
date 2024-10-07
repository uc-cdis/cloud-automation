package main

import (
	"context"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"os"

	"github.com/go-logr/logr"
	admissionv1 "k8s.io/api/admission/v1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"
	//jsonpatch "gomodules.xyz/jsonpatch/v2"
)

// DaemonSetMutator implements admission.Handler
type DaemonSetMutator struct {
	Decoder *admission.Decoder
	Logger  logr.Logger
}

func (m *DaemonSetMutator) Handle(ctx context.Context, req admission.Request) admission.Response {
	ds := &appsv1.DaemonSet{}
	err := m.Decoder.Decode(req, ds)
	if err != nil {
		m.Logger.Error(err, "Failed to decode request")
		return admission.Errored(http.StatusBadRequest, err)
	}

	// Add node affinity to avoid Fargate nodes
	affinity := &corev1.Affinity{
		NodeAffinity: &corev1.NodeAffinity{
			RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
				NodeSelectorTerms: []corev1.NodeSelectorTerm{
					{
						MatchExpressions: []corev1.NodeSelectorRequirement{
							{
								Key:      "eks.amazonaws.com/compute-type",
								Operator: corev1.NodeSelectorOpNotIn,
								Values:   []string{"fargate"},
							},
						},
					},
				},
			},
		},
	}

	if ds.Spec.Template.Spec.Affinity == nil {
		ds.Spec.Template.Spec.Affinity = affinity
	} else {
		ds.Spec.Template.Spec.Affinity.NodeAffinity = affinity.NodeAffinity
	}

	marshalledDS, err := json.Marshal(ds)
	if err != nil {
		m.Logger.Error(err, "Failed to marshal response")
		return admission.Errored(http.StatusInternalServerError, err)
	}

	return admission.PatchResponseFromRaw(req.Object.Raw, marshalledDS)
}

func main() {
	logger := zap.New(zap.UseDevMode(true))
	ctrl.SetLogger(logger)
	log := ctrl.Log.WithName("webhook")

	scheme := runtime.NewScheme()
	decoder := admission.NewDecoder(scheme)

	m := &DaemonSetMutator{Decoder: decoder, Logger: log}

	http.HandleFunc("/mutate", func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		body, err := ioutil.ReadAll(r.Body)
		if err != nil {
			log.Error(err, "Could not read request body")
			http.Error(w, "could not read request body", http.StatusBadRequest)
			return
		}
		log.Info("Received request", "body", string(body))

		review := &admissionv1.AdmissionReview{}
		err = json.Unmarshal(body, review)
		if err != nil {
			log.Error(err, "Could not decode request body")
			http.Error(w, "could not decode request body", http.StatusBadRequest)
			return
		}

		req := admission.Request{
			AdmissionRequest: *review.Request,
		}

		resp := m.Handle(ctx, req)

		var patchBytes []byte
		if resp.Patches != nil {
			patchBytes, err = json.Marshal(resp.Patches)
			if err != nil {
				log.Error(err, "Could not marshal patches")
				http.Error(w, "could not marshal patches", http.StatusInternalServerError)
				return
			}
		}

		review.Response = &admissionv1.AdmissionResponse{
			UID:     review.Request.UID,
			Allowed: resp.Allowed,
			Result:  resp.Result,
			Patch:   patchBytes,
			PatchType: func() *admissionv1.PatchType {
				if len(patchBytes) > 0 {
					pt := admissionv1.PatchTypeJSONPatch
					return &pt
				}
				return nil
			}(),
		}

		respBytes, err := json.Marshal(review)
		if err != nil {
			log.Error(err, "Could not encode response")
			http.Error(w, "could not encode response", http.StatusInternalServerError)
			return
		}

		_, err = w.Write(respBytes)
		if err != nil {
			log.Error(err, "Could not write response")
		}
	})

	log.Info("Starting webhook server")
	if err := http.ListenAndServeTLS(":8443", "/etc/webhook/certs/tls.crt", "/etc/webhook/certs/tls.key", nil); err != nil {
		log.Error(err, "Failed to start webhook server")
		os.Exit(1)
	}
}

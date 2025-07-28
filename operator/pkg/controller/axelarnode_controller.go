package controller

import (
	"context"
	"fmt"
	"time"

	"github.com/go-logr/logr"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

	blockchainv1alpha1 "github.com/axelar-network/axelar-k8s-operator/pkg/apis/blockchain/v1alpha1"
)

// AxelarNodeReconciler reconciles an AxelarNode object
type AxelarNodeReconciler struct {
	client.Client
	Log    logr.Logger
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=blockchain.axelar.network,resources=axelarnodes,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=blockchain.axelar.network,resources=axelarnodes/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=blockchain.axelar.network,resources=axelarnodes/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=secrets,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=persistentvolumeclaims,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch
// +kubebuilder:rbac:groups="",resources=events,verbs=create;patch

// Reconcile handles AxelarNode reconciliation
func (r *AxelarNodeReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := r.Log.WithValues("axelarnode", req.NamespacedName)

	// Fetch the AxelarNode instance
	axelarNode := &blockchainv1alpha1.AxelarNode{}
	err := r.Get(ctx, req.NamespacedName, axelarNode)
	if err != nil {
		if errors.IsNotFound(err) {
			log.Info("AxelarNode resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		log.Error(err, "Failed to get AxelarNode")
		return ctrl.Result{}, err
	}

	// Handle deletion
	if axelarNode.DeletionTimestamp != nil {
		return r.handleDeletion(ctx, axelarNode)
	}

	// Add finalizer if not present
	if !controllerutil.ContainsFinalizer(axelarNode, "axelarnode.blockchain.axelar.network/finalizer") {
		controllerutil.AddFinalizer(axelarNode, "axelarnode.blockchain.axelar.network/finalizer")
		return ctrl.Result{}, r.Update(ctx, axelarNode)
	}

	// Update status phase
	if axelarNode.Status.Phase == "" {
		axelarNode.Status.Phase = "Initializing"
		if err := r.Status().Update(ctx, axelarNode); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Reconcile resources
	if err := r.reconcileConfigMap(ctx, axelarNode); err != nil {
		return ctrl.Result{}, err
	}

	if err := r.reconcileSecret(ctx, axelarNode); err != nil {
		return ctrl.Result{}, err
	}

	if err := r.reconcilePVC(ctx, axelarNode); err != nil {
		return ctrl.Result{}, err
	}

	if err := r.reconcileService(ctx, axelarNode); err != nil {
		return ctrl.Result{}, err
	}

	if err := r.reconcileDeployment(ctx, axelarNode); err != nil {
		return ctrl.Result{}, err
	}

	// Update status based on deployment
	if err := r.updateStatus(ctx, axelarNode); err != nil {
		return ctrl.Result{}, err
	}

	// Schedule next reconciliation
	return ctrl.Result{RequeueAfter: time.Minute * 5}, nil
}

// handleDeletion handles resource cleanup
func (r *AxelarNodeReconciler) handleDeletion(ctx context.Context, axelarNode *blockchainv1alpha1.AxelarNode) (ctrl.Result, error) {
	log := r.Log.WithValues("axelarnode", axelarNode.Name)

	// Perform cleanup operations here
	log.Info("Cleaning up AxelarNode resources")

	// Remove finalizer
	controllerutil.RemoveFinalizer(axelarNode, "axelarnode.blockchain.axelar.network/finalizer")
	return ctrl.Result{}, r.Update(ctx, axelarNode)
}

// reconcileConfigMap creates or updates the ConfigMap
func (r *AxelarNodeReconciler) reconcileConfigMap(ctx context.Context, axelarNode *blockchainv1alpha1.AxelarNode) error {
	configMap := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      axelarNode.Name + "-config",
			Namespace: axelarNode.Namespace,
		},
		Data: r.generateConfigMapData(axelarNode),
	}

	if err := controllerutil.SetControllerReference(axelarNode, configMap, r.Scheme); err != nil {
		return err
	}

	found := &corev1.ConfigMap{}
	err := r.Get(ctx, types.NamespacedName{Name: configMap.Name, Namespace: configMap.Namespace}, found)
	if err != nil && errors.IsNotFound(err) {
		return r.Create(ctx, configMap)
	} else if err != nil {
		return err
	}

	// Update if needed
	found.Data = configMap.Data
	return r.Update(ctx, found)
}

// generateConfigMapData generates configuration data
func (r *AxelarNodeReconciler) generateConfigMapData(axelarNode *blockchainv1alpha1.AxelarNode) map[string]string {
	chainId := "axelar-testnet-lisbon-3"
	if axelarNode.Spec.Network == "mainnet" {
		chainId = "axelar-dojo-1"
	}

	return map[string]string{
		"app.toml": fmt.Sprintf(`
# Axelar Node Configuration
minimum-gas-prices = "0.007uaxl"
pruning = "default"
halt-height = 0

[telemetry]
enabled = %t
prometheus-retention-time = 60

[api]
enable = %t
address = "tcp://0.0.0.0:%d"

[grpc]
enable = true
address = "0.0.0.0:9090"
`, axelarNode.Spec.Monitoring.Enabled, axelarNode.Spec.Networking.API.Enabled, axelarNode.Spec.Networking.API.Port),

		"config.toml": fmt.Sprintf(`
# Tendermint Configuration
moniker = "%s"
fast_sync = true
db_backend = "goleveldb"
log_level = "info"
log_format = "json"

[rpc]
laddr = "tcp://0.0.0.0:%d"
cors_allowed_origins = []
unsafe = false

[p2p]
laddr = "tcp://0.0.0.0:%d"
external_address = "%s"
persistent_peers = "%s"
seeds = "%s"
max_num_inbound_peers = 40
max_num_outbound_peers = 10

[instrumentation]
prometheus = %t
prometheus_listen_addr = ":%d"
`, axelarNode.Spec.Moniker, axelarNode.Spec.Networking.RPC.Port, 
   axelarNode.Spec.Networking.P2P.Port, axelarNode.Spec.Networking.P2P.ExternalAddress,
   joinStrings(axelarNode.Spec.Networking.P2P.PersistentPeers), 
   joinStrings(axelarNode.Spec.Networking.P2P.Seeds),
   axelarNode.Spec.Monitoring.Enabled, axelarNode.Spec.Monitoring.Prometheus.Port),

		"chain-id": chainId,
		"network":  axelarNode.Spec.Network,
	}
}

// reconcileSecret creates or updates secrets
func (r *AxelarNodeReconciler) reconcileSecret(ctx context.Context, axelarNode *blockchainv1alpha1.AxelarNode) error {
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      axelarNode.Name + "-secrets",
			Namespace: axelarNode.Namespace,
		},
		Type: corev1.SecretTypeOpaque,
		Data: map[string][]byte{
			"keyring-password": []byte("default-password-change-me"),
		},
	}

	if axelarNode.Spec.Validator != nil && axelarNode.Spec.Validator.Enabled {
		secret.Data["tofnd-password"] = []byte("default-tofnd-password-change-me")
	}

	if err := controllerutil.SetControllerReference(axelarNode, secret, r.Scheme); err != nil {
		return err
	}

	found := &corev1.Secret{}
	err := r.Get(ctx, types.NamespacedName{Name: secret.Name, Namespace: secret.Namespace}, found)
	if err != nil && errors.IsNotFound(err) {
		return r.Create(ctx, secret)
	}
	return err
}

// reconcilePVC creates persistent volume claims
func (r *AxelarNodeReconciler) reconcilePVC(ctx context.Context, axelarNode *blockchainv1alpha1.AxelarNode) error {
	// Main data PVC
	pvc := r.createPVC(axelarNode, "data", axelarNode.Spec.Storage.Size)
	if err := r.createOrUpdatePVC(ctx, pvc); err != nil {
		return err
	}

	// Shared data PVC
	sharedPVC := r.createPVC(axelarNode, "shared", "10Gi")
	return r.createOrUpdatePVC(ctx, sharedPVC)
}

// createPVC creates a PVC object
func (r *AxelarNodeReconciler) createPVC(axelarNode *blockchainv1alpha1.AxelarNode, suffix, size string) *corev1.PersistentVolumeClaim {
	pvc := &corev1.PersistentVolumeClaim{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-%s", axelarNode.Name, suffix),
			Namespace: axelarNode.Namespace,
		},
		Spec: corev1.PersistentVolumeClaimSpec{
			AccessModes: []corev1.PersistentVolumeAccessMode{corev1.ReadWriteOnce},
			Resources: corev1.ResourceRequirements{
				Requests: corev1.ResourceList{
					corev1.ResourceStorage: resource.MustParse(size),
				},
			},
		},
	}

	if axelarNode.Spec.Storage.StorageClass != "" {
		pvc.Spec.StorageClassName = &axelarNode.Spec.Storage.StorageClass
	}

	controllerutil.SetControllerReference(axelarNode, pvc, r.Scheme)
	return pvc
}

// createOrUpdatePVC creates or updates a PVC
func (r *AxelarNodeReconciler) createOrUpdatePVC(ctx context.Context, pvc *corev1.PersistentVolumeClaim) error {
	found := &corev1.PersistentVolumeClaim{}
	err := r.Get(ctx, types.NamespacedName{Name: pvc.Name, Namespace: pvc.Namespace}, found)
	if err != nil && errors.IsNotFound(err) {
		return r.Create(ctx, pvc)
	}
	return err
}

// reconcileService creates or updates the service
func (r *AxelarNodeReconciler) reconcileService(ctx context.Context, axelarNode *blockchainv1alpha1.AxelarNode) error {
	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      axelarNode.Name + "-service",
			Namespace: axelarNode.Namespace,
			Annotations: map[string]string{
				"prometheus.io/scrape": "true",
				"prometheus.io/port":   fmt.Sprintf("%d", axelarNode.Spec.Monitoring.Prometheus.Port),
				"prometheus.io/path":   axelarNode.Spec.Monitoring.Prometheus.Path,
			},
		},
		Spec: corev1.ServiceSpec{
			Selector: map[string]string{
				"app": axelarNode.Name,
			},
			Ports: []corev1.ServicePort{
				{
					Name:       "rpc",
					Port:       axelarNode.Spec.Networking.RPC.Port,
					TargetPort: intstr.FromInt(int(axelarNode.Spec.Networking.RPC.Port)),
				},
				{
					Name:       "p2p",
					Port:       axelarNode.Spec.Networking.P2P.Port,
					TargetPort: intstr.FromInt(int(axelarNode.Spec.Networking.P2P.Port)),
				},
				{
					Name:       "api",
					Port:       axelarNode.Spec.Networking.API.Port,
					TargetPort: intstr.FromInt(int(axelarNode.Spec.Networking.API.Port)),
				},
				{
					Name:       "prometheus",
					Port:       axelarNode.Spec.Monitoring.Prometheus.Port,
					TargetPort: intstr.FromInt(int(axelarNode.Spec.Monitoring.Prometheus.Port)),
				},
			},
		},
	}

	if err := controllerutil.SetControllerReference(axelarNode, service, r.Scheme); err != nil {
		return err
	}

	found := &corev1.Service{}
	err := r.Get(ctx, types.NamespacedName{Name: service.Name, Namespace: service.Namespace}, found)
	if err != nil && errors.IsNotFound(err) {
		return r.Create(ctx, service)
	} else if err != nil {
		return err
	}

	// Update service
	found.Spec.Ports = service.Spec.Ports
	found.Annotations = service.Annotations
	return r.Update(ctx, found)
}

// reconcileDeployment creates or updates the deployment
func (r *AxelarNodeReconciler) reconcileDeployment(ctx context.Context, axelarNode *blockchainv1alpha1.AxelarNode) error {
	deployment := r.createDeployment(axelarNode)

	if err := controllerutil.SetControllerReference(axelarNode, deployment, r.Scheme); err != nil {
		return err
	}

	found := &appsv1.Deployment{}
	err := r.Get(ctx, types.NamespacedName{Name: deployment.Name, Namespace: deployment.Namespace}, found)
	if err != nil && errors.IsNotFound(err) {
		return r.Create(ctx, deployment)
	} else if err != nil {
		return err
	}

	// Update deployment if needed
	if !r.deploymentEqual(found, deployment) {
		found.Spec = deployment.Spec
		return r.Update(ctx, found)
	}

	return nil
}

// createDeployment creates a deployment object
func (r *AxelarNodeReconciler) createDeployment(axelarNode *blockchainv1alpha1.AxelarNode) *appsv1.Deployment {
	replicas := int32(1)
	
	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      axelarNode.Name,
			Namespace: axelarNode.Namespace,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Strategy: appsv1.DeploymentStrategy{
				Type: appsv1.RecreateDeploymentStrategyType,
			},
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": axelarNode.Name,
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app": axelarNode.Name,
					},
					Annotations: map[string]string{
						"prometheus.io/scrape": "true",
						"prometheus.io/port":   fmt.Sprintf("%d", axelarNode.Spec.Monitoring.Prometheus.Port),
						"prometheus.io/path":   axelarNode.Spec.Monitoring.Prometheus.Path,
					},
				},
				Spec: r.createPodSpec(axelarNode),
			},
		},
	}

	return deployment
}

// createPodSpec creates the pod specification
func (r *AxelarNodeReconciler) createPodSpec(axelarNode *blockchainv1alpha1.AxelarNode) corev1.PodSpec {
	containers := []corev1.Container{
		{
			Name:  "axelar-node",
			Image: fmt.Sprintf("%s:%s", axelarNode.Spec.Image.Repository, axelarNode.Spec.Image.Tag),
			ImagePullPolicy: axelarNode.Spec.Image.PullPolicy,
			Command: []string{"startNodeProc"},
			Env: []corev1.EnvVar{
				{Name: "HOME", Value: "/home/axelard"},
				{Name: "START_REST", Value: "true"},
				{Name: "NODE_MONIKER", Value: axelarNode.Spec.Moniker},
				{
					Name: "KEYRING_PASSWORD",
					ValueFrom: &corev1.EnvVarSource{
						SecretKeyRef: &corev1.SecretKeySelector{
							LocalObjectReference: corev1.LocalObjectReference{
								Name: axelarNode.Name + "-secrets",
							},
							Key: "keyring-password",
						},
					},
				},
			},
			Ports: []corev1.ContainerPort{
				{Name: "rpc", ContainerPort: axelarNode.Spec.Networking.RPC.Port},
				{Name: "p2p", ContainerPort: axelarNode.Spec.Networking.P2P.Port},
				{Name: "api", ContainerPort: axelarNode.Spec.Networking.API.Port},
				{Name: "prometheus", ContainerPort: axelarNode.Spec.Monitoring.Prometheus.Port},
			},
			Resources: axelarNode.Spec.Resources,
			VolumeMounts: []corev1.VolumeMount{
				{Name: "data", MountPath: "/home/axelard/.axelar"},
				{Name: "shared", MountPath: "/home/axelard/shared"},
				{Name: "config", MountPath: "/home/axelard/config"},
			},
			LivenessProbe: &corev1.Probe{
				ProbeHandler: corev1.ProbeHandler{
					HTTPGet: &corev1.HTTPGetAction{
						Path: "/health",
						Port: intstr.FromInt(int(axelarNode.Spec.Monitoring.Prometheus.Port)),
					},
				},
				InitialDelaySeconds: 120,
				PeriodSeconds:       30,
			},
			ReadinessProbe: &corev1.Probe{
				ProbeHandler: corev1.ProbeHandler{
					HTTPGet: &corev1.HTTPGetAction{
						Path: "/health",
						Port: intstr.FromInt(int(axelarNode.Spec.Monitoring.Prometheus.Port)),
					},
				},
				InitialDelaySeconds: 60,
				PeriodSeconds:       10,
			},
		},
	}

	// Add validator containers if enabled
	if axelarNode.Spec.Validator != nil && axelarNode.Spec.Validator.Enabled {
		containers = append(containers, r.createValidatorContainers(axelarNode)...)
	}

	return corev1.PodSpec{
		Containers: containers,
		Volumes: []corev1.Volume{
			{
				Name: "data",
				VolumeSource: corev1.VolumeSource{
					PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
						ClaimName: axelarNode.Name + "-data",
					},
				},
			},
			{
				Name: "shared",
				VolumeSource: corev1.VolumeSource{
					PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
						ClaimName: axelarNode.Name + "-shared",
					},
				},
			},
			{
				Name: "config",
				VolumeSource: corev1.VolumeSource{
					ConfigMap: &corev1.ConfigMapVolumeSource{
						LocalObjectReference: corev1.LocalObjectReference{
							Name: axelarNode.Name + "-config",
						},
					},
				},
			},
		},
		SecurityContext: axelarNode.Spec.Security.PodSecurityContext,
	}
}

// createValidatorContainers creates validator-specific containers
func (r *AxelarNodeReconciler) createValidatorContainers(axelarNode *blockchainv1alpha1.AxelarNode) []corev1.Container {
	return []corev1.Container{
		{
			Name:  "vald",
			Image: fmt.Sprintf("%s:%s", axelarNode.Spec.Image.Repository, axelarNode.Spec.Image.Tag),
			Command: []string{"sh", "-c", "sleep 60 && exec vald-start"},
			Env: []corev1.EnvVar{
				{Name: "HOME", Value: "/home/axelard"},
				{
					Name: "KEYRING_PASSWORD",
					ValueFrom: &corev1.EnvVarSource{
						SecretKeyRef: &corev1.SecretKeySelector{
							LocalObjectReference: corev1.LocalObjectReference{
								Name: axelarNode.Name + "-secrets",
							},
							Key: "keyring-password",
						},
					},
				},
			},
			VolumeMounts: []corev1.VolumeMount{
				{Name: "data", MountPath: "/home/axelard/.axelar"},
				{Name: "shared", MountPath: "/home/axelard/shared"},
			},
		},
		{
			Name:  "tofnd",
			Image: "axelarnet/tofnd:v0.10.1",
			Command: []string{"tofnd"},
			Args: []string{
				"-m", "/home/axelard/shared/tofnd.txt",
				"-d", "/home/axelard/.tofnd",
			},
			Env: []corev1.EnvVar{
				{
					Name: "TOFND_PASSWORD",
					ValueFrom: &corev1.EnvVarSource{
						SecretKeyRef: &corev1.SecretKeySelector{
							LocalObjectReference: corev1.LocalObjectReference{
								Name: axelarNode.Name + "-secrets",
							},
							Key: "tofnd-password",
						},
					},
				},
			},
			Ports: []corev1.ContainerPort{
				{Name: "tofnd", ContainerPort: 50051},
			},
			VolumeMounts: []corev1.VolumeMount{
				{Name: "shared", MountPath: "/home/axelard/shared"},
			},
		},
	}
}

// updateStatus updates the AxelarNode status
func (r *AxelarNodeReconciler) updateStatus(ctx context.Context, axelarNode *blockchainv1alpha1.AxelarNode) error {
	// Get deployment status
	deployment := &appsv1.Deployment{}
	err := r.Get(ctx, types.NamespacedName{Name: axelarNode.Name, Namespace: axelarNode.Namespace}, deployment)
	if err != nil {
		return err
	}

	// Update phase based on deployment status
	if deployment.Status.ReadyReplicas > 0 {
		axelarNode.Status.Phase = "Running"
	} else if deployment.Status.Replicas > 0 {
		axelarNode.Status.Phase = "Syncing"
	} else {
		axelarNode.Status.Phase = "Pending"
	}

	// TODO: Get actual metrics from the node
	axelarNode.Status.SyncInfo = blockchainv1alpha1.SyncInfo{
		CurrentHeight: 12345,
		LatestHeight:  12345,
		CatchingUp:    false,
		LastSyncTime:  &metav1.Time{Time: time.Now()},
	}

	axelarNode.Status.NetworkInfo = blockchainv1alpha1.NetworkInfo{
		Peers:   10,
		NodeID:  "mock-node-id",
		Network: axelarNode.Spec.Network,
	}

	return r.Status().Update(ctx, axelarNode)
}

// deploymentEqual compares two deployments
func (r *AxelarNodeReconciler) deploymentEqual(a, b *appsv1.Deployment) bool {
	// Simplified comparison - in production, you'd want more thorough comparison
	return a.Spec.Template.Spec.Containers[0].Image == b.Spec.Template.Spec.Containers[0].Image
}

// joinStrings joins string slice with commas
func joinStrings(strs []string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += "," + strs[i]
	}
	return result
}

// SetupWithManager sets up the controller with the Manager
func (r *AxelarNodeReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&blockchainv1alpha1.AxelarNode{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&corev1.ConfigMap{}).
		Owns(&corev1.Secret{}).
		Owns(&corev1.PersistentVolumeClaim{}).
		Complete(r)
}

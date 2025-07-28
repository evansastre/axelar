package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// AxelarNodeSpec defines the desired state of AxelarNode
type AxelarNodeSpec struct {
	// NodeType specifies the type of Axelar node
	// +kubebuilder:validation:Enum=validator;sentry;seed;observer
	// +kubebuilder:default=observer
	NodeType string `json:"nodeType"`

	// Network specifies which Axelar network to connect to
	// +kubebuilder:validation:Enum=mainnet;testnet
	// +kubebuilder:default=testnet
	Network string `json:"network"`

	// Moniker is the human-readable name for this node
	// +kubebuilder:default="axelar-k8s-node"
	Moniker string `json:"moniker,omitempty"`

	// Image configuration for the Axelar node
	Image ImageSpec `json:"image,omitempty"`

	// Resources defines the compute resources for the node
	Resources corev1.ResourceRequirements `json:"resources,omitempty"`

	// Storage configuration for the node
	Storage StorageSpec `json:"storage,omitempty"`

	// Validator-specific configuration
	Validator *ValidatorSpec `json:"validator,omitempty"`

	// Networking configuration
	Networking NetworkingSpec `json:"networking,omitempty"`

	// Monitoring configuration
	Monitoring MonitoringSpec `json:"monitoring,omitempty"`

	// Upgrade configuration
	Upgrade UpgradeSpec `json:"upgrade,omitempty"`

	// Security configuration
	Security SecuritySpec `json:"security,omitempty"`
}

// ImageSpec defines the container image configuration
type ImageSpec struct {
	// Repository is the container image repository
	// +kubebuilder:default="axelarnet/axelar-core"
	Repository string `json:"repository"`

	// Tag is the container image tag
	// +kubebuilder:default="v0.35.5"
	Tag string `json:"tag"`

	// PullPolicy is the image pull policy
	// +kubebuilder:default="IfNotPresent"
	PullPolicy corev1.PullPolicy `json:"pullPolicy,omitempty"`
}

// StorageSpec defines storage configuration
type StorageSpec struct {
	// Size is the storage size
	// +kubebuilder:default="500Gi"
	Size string `json:"size,omitempty"`

	// StorageClass for persistent volumes
	// +kubebuilder:default="standard"
	StorageClass string `json:"storageClass,omitempty"`

	// Backup configuration
	Backup BackupSpec `json:"backup,omitempty"`
}

// BackupSpec defines backup configuration
type BackupSpec struct {
	// Enabled indicates if backups are enabled
	Enabled bool `json:"enabled,omitempty"`

	// Schedule is the cron schedule for backups
	// +kubebuilder:default="0 2 * * *"
	Schedule string `json:"schedule,omitempty"`

	// Retention period for backups
	// +kubebuilder:default="7d"
	Retention string `json:"retention,omitempty"`
}

// ValidatorSpec defines validator-specific configuration
type ValidatorSpec struct {
	// Enabled indicates if this node is a validator
	Enabled bool `json:"enabled,omitempty"`

	// KeyManagement configuration
	KeyManagement KeyManagementSpec `json:"keyManagement,omitempty"`

	// Slashing protection configuration
	Slashing SlashingSpec `json:"slashing,omitempty"`
}

// KeyManagementSpec defines key management configuration
type KeyManagementSpec struct {
	// AutoRotation enables automatic key rotation
	AutoRotation bool `json:"autoRotation,omitempty"`

	// RotationSchedule is the cron schedule for key rotation
	// +kubebuilder:default="0 0 1 * *"
	RotationSchedule string `json:"rotationSchedule,omitempty"`

	// BackupKeys enables key backup
	// +kubebuilder:default=true
	BackupKeys bool `json:"backupKeys,omitempty"`
}

// SlashingSpec defines slashing protection configuration
type SlashingSpec struct {
	// Protection enables slashing protection
	// +kubebuilder:default=true
	Protection bool `json:"protection,omitempty"`

	// MaxMissedBlocks before alerting
	// +kubebuilder:default=50
	MaxMissedBlocks int32 `json:"maxMissedBlocks,omitempty"`
}

// NetworkingSpec defines networking configuration
type NetworkingSpec struct {
	// P2P configuration
	P2P P2PSpec `json:"p2p,omitempty"`

	// RPC configuration
	RPC RPCSpec `json:"rpc,omitempty"`

	// API configuration
	API APISpec `json:"api,omitempty"`
}

// P2PSpec defines P2P networking configuration
type P2PSpec struct {
	// Port for P2P communication
	// +kubebuilder:default=26656
	Port int32 `json:"port,omitempty"`

	// ExternalAddress for P2P
	ExternalAddress string `json:"externalAddress,omitempty"`

	// PersistentPeers list
	PersistentPeers []string `json:"persistentPeers,omitempty"`

	// Seeds list
	Seeds []string `json:"seeds,omitempty"`
}

// RPCSpec defines RPC configuration
type RPCSpec struct {
	// Enabled indicates if RPC is enabled
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Port for RPC
	// +kubebuilder:default=26657
	Port int32 `json:"port,omitempty"`

	// CORS enables CORS
	CORS bool `json:"cors,omitempty"`
}

// APISpec defines API configuration
type APISpec struct {
	// Enabled indicates if API is enabled
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Port for API
	// +kubebuilder:default=1317
	Port int32 `json:"port,omitempty"`
}

// MonitoringSpec defines monitoring configuration
type MonitoringSpec struct {
	// Enabled indicates if monitoring is enabled
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Prometheus configuration
	Prometheus PrometheusSpec `json:"prometheus,omitempty"`

	// Alerts configuration
	Alerts AlertsSpec `json:"alerts,omitempty"`
}

// PrometheusSpec defines Prometheus configuration
type PrometheusSpec struct {
	// Port for Prometheus metrics
	// +kubebuilder:default=26660
	Port int32 `json:"port,omitempty"`

	// Path for metrics endpoint
	// +kubebuilder:default="/metrics"
	Path string `json:"path,omitempty"`
}

// AlertsSpec defines alerting configuration
type AlertsSpec struct {
	// Enabled indicates if alerts are enabled
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Slack configuration
	Slack SlackSpec `json:"slack,omitempty"`
}

// SlackSpec defines Slack alerting configuration
type SlackSpec struct {
	// Webhook URL for Slack
	Webhook string `json:"webhook,omitempty"`

	// Channel for Slack notifications
	Channel string `json:"channel,omitempty"`
}

// UpgradeSpec defines upgrade configuration
type UpgradeSpec struct {
	// Strategy for upgrades
	// +kubebuilder:validation:Enum=rolling;recreate;manual
	// +kubebuilder:default=rolling
	Strategy string `json:"strategy,omitempty"`

	// AutoUpgrade enables automatic upgrades
	AutoUpgrade bool `json:"autoUpgrade,omitempty"`

	// PreUpgradeBackup enables backup before upgrade
	// +kubebuilder:default=true
	PreUpgradeBackup bool `json:"preUpgradeBackup,omitempty"`

	// RollbackOnFailure enables automatic rollback on failure
	// +kubebuilder:default=true
	RollbackOnFailure bool `json:"rollbackOnFailure,omitempty"`
}

// SecuritySpec defines security configuration
type SecuritySpec struct {
	// PodSecurityContext for the pod
	PodSecurityContext *corev1.PodSecurityContext `json:"podSecurityContext,omitempty"`

	// NetworkPolicies enables network policies
	// +kubebuilder:default=true
	NetworkPolicies bool `json:"networkPolicies,omitempty"`

	// SecretManagement configuration
	SecretManagement SecretManagementSpec `json:"secretManagement,omitempty"`
}

// SecretManagementSpec defines secret management configuration
type SecretManagementSpec struct {
	// Provider for secret management
	// +kubebuilder:validation:Enum=kubernetes;vault;aws-secrets-manager
	// +kubebuilder:default=kubernetes
	Provider string `json:"provider,omitempty"`

	// AutoRotation enables automatic secret rotation
	AutoRotation bool `json:"autoRotation,omitempty"`
}

// AxelarNodeStatus defines the observed state of AxelarNode
type AxelarNodeStatus struct {
	// Phase represents the current phase of the node
	// +kubebuilder:validation:Enum=Pending;Initializing;Syncing;Running;Upgrading;Failed
	Phase string `json:"phase,omitempty"`

	// Conditions represent the latest available observations
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// SyncInfo contains blockchain sync information
	SyncInfo SyncInfo `json:"syncInfo,omitempty"`

	// NetworkInfo contains network information
	NetworkInfo NetworkInfo `json:"networkInfo,omitempty"`

	// ValidatorInfo contains validator information
	ValidatorInfo *ValidatorInfo `json:"validatorInfo,omitempty"`

	// LastBackup timestamp
	LastBackup *metav1.Time `json:"lastBackup,omitempty"`

	// LastUpgrade timestamp
	LastUpgrade *metav1.Time `json:"lastUpgrade,omitempty"`
}

// SyncInfo contains blockchain synchronization information
type SyncInfo struct {
	// CurrentHeight is the current block height
	CurrentHeight int64 `json:"currentHeight,omitempty"`

	// LatestHeight is the latest known block height
	LatestHeight int64 `json:"latestHeight,omitempty"`

	// CatchingUp indicates if the node is catching up
	CatchingUp bool `json:"catchingUp,omitempty"`

	// LastSyncTime is the last sync timestamp
	LastSyncTime *metav1.Time `json:"lastSyncTime,omitempty"`
}

// NetworkInfo contains network information
type NetworkInfo struct {
	// Peers is the number of connected peers
	Peers int32 `json:"peers,omitempty"`

	// NodeID is the node identifier
	NodeID string `json:"nodeId,omitempty"`

	// Network is the network name
	Network string `json:"network,omitempty"`
}

// ValidatorInfo contains validator information
type ValidatorInfo struct {
	// Address is the validator address
	Address string `json:"address,omitempty"`

	// VotingPower is the validator voting power
	VotingPower int64 `json:"votingPower,omitempty"`

	// MissedBlocks is the number of missed blocks
	MissedBlocks int32 `json:"missedBlocks,omitempty"`

	// LastSignedHeight is the last signed block height
	LastSignedHeight int64 `json:"lastSignedHeight,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Type",type="string",JSONPath=".spec.nodeType"
// +kubebuilder:printcolumn:name="Network",type="string",JSONPath=".spec.network"
// +kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Height",type="integer",JSONPath=".status.syncInfo.currentHeight"
// +kubebuilder:printcolumn:name="Peers",type="integer",JSONPath=".status.networkInfo.peers"
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

// AxelarNode is the Schema for the axelarnodes API
type AxelarNode struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   AxelarNodeSpec   `json:"spec,omitempty"`
	Status AxelarNodeStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// AxelarNodeList contains a list of AxelarNode
type AxelarNodeList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []AxelarNode `json:"items"`
}

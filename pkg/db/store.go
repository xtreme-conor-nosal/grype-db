package db

type Store interface {
	StoreReader
	StoreWriter
}

type StoreReader interface {
	IDReader
	VulnerabilityStoreReader
	VulnerabilityMetadataStoreReader
}

type StoreWriter interface {
	IDWriter
	VulnerabilityStoreWriter
	VulnerabilityMetadataStoreWriter
}

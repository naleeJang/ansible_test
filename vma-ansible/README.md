# VMware → OpenShift Virtualization 마이그레이션

**환경**
- Red Hat Ansible Automation Platform 2.6
- VMware vCenter 7.x / 8.x
- OpenShift Virtualization 4.20

## 디렉터리 구조
```
.
├── ansible.cfg
├── inventory.yml
├── collections/
│   └── requirements.yml             # AAP Project Sync 시 자동 설치
├── vars/
│   └── main.yml                     # 비밀이 아닌 변수 (대상 VM, 매핑 등)
├── roles/
│   └── vmware_vm_info/              # VM 정보 수집 role
│       ├── defaults/main.yml
│       └── tasks/main.yml
└── 01_gather_vmware_vm_info.yml     # 1단계 플레이북
```

## 1단계: VM 정보 수집

### 사용 collection
| Collection | 용도 |
|---|---|
| `vmware.vmware` | Red Hat 인증, AAP 지원. 클러스터/VM 목록 조회 |
| `community.vmware` | guest_info, disk_info, network 등 세부 정보 |

두 collection 모두 `collections/requirements.yml`에 명시되어 있어 AAP Project Sync 시 자동 설치됩니다.

### AAP 설정 방법

#### 1) Execution Environment
`vmware.vmware`, `community.vmware`, `kubernetes.core`가 포함된 EE를 사용합니다. AAP 2.6의 기본 `ee-supported-rhel9` 또는 커스텀 EE를 빌드해 사용하세요.

#### 2) Credential
**Type: VMware vCenter** Credential을 생성합니다. AAP가 자동으로 다음 환경변수를 주입합니다.
- `VMWARE_HOST`
- `VMWARE_USER`
- `VMWARE_PASSWORD`
- `VMWARE_VALIDATE_CERTS`

플레이북은 이 환경변수를 lookup해서 사용하므로, 비밀번호를 변수 파일에 둘 필요가 없습니다.

#### 3) Project
이 저장소(Git)를 Project로 등록합니다.

#### 4) Job Template
- Inventory: 기본 인벤토리 (localhost)
- Project: 위에서 만든 Project
- Playbook: `01_gather_vmware_vm_info.yml`
- Credentials: 위에서 만든 VMware vCenter Credential
- Variables / Survey (권장):
  ```yaml
  vcenter_datacenter: "Datacenter"
  target_vms:
    - "rhel9-app01"
    - "rhel9-app02"
  include_templates: false
  ```

### 수집되는 정보

| 필드 | 설명 | OV 4.20에서의 활용 |
|---|---|---|
| `source.uuid` | VMware UUID | VirtualMachine annotation |
| `source.power_state` | 전원 상태 | 마이그레이션 가능 여부 판정 |
| `source.guest_id` | VMware guest ID (rhel9_64Guest 등) | OS 라벨/템플릿 매핑 |
| `source.firmware` | `bios` 또는 `efi` | `spec.template.spec.domain.firmware` |
| `source.hw_version` | vmx 버전 | machineType 결정 |
| `source.vmware_tools` | Tools 상태 | 마이그레이션 전 사전 점검 |
| `cpu.cores`, `cpu.cores_per_socket` | vCPU 구성 | `spec.template.spec.domain.cpu` |
| `memory_mb` | 메모리 | `spec.template.spec.domain.resources.requests.memory` |
| `disks[]` | 디스크 크기/타입/datastore | DataVolume(CDI) 생성 입력 |
| `networks[]` | NIC/MAC/portgroup | NetworkAttachmentDefinition 매핑 |

### 결과물

플레이북 실행 후 `vm_inventory/` 디렉터리에 다음 파일이 생성됩니다.

```
vm_inventory/
├── vm_inventory.yml      # 전체 VM 통합 정보 (YAML)
├── vm_inventory.json     # 전체 VM 통합 정보 (JSON) - 다음 단계 입력용
└── <vm-name>.yml         # VM별 개별 정보
```

또한 `set_stats`로 다음 artifact가 등록되어 **AAP Workflow의 다음 Job**에서 바로 받을 수 있습니다.
- `vmware_vm_inventory` : VM 정보 리스트
- `vmware_failed_vms`   : 수집 실패 VM 리스트
- `vmware_inventory_file`: 결과 파일 경로

### 로컬 테스트 (AAP 없이)
```bash
ansible-galaxy collection install -r collections/requirements.yml

export VMWARE_HOST=vcenter.example.com
export VMWARE_USER='administrator@vsphere.local'
export VMWARE_PASSWORD='your-password'
export VMWARE_VALIDATE_CERTS=false

ansible-playbook 01_gather_vmware_vm_info.yml
```

## 다음 단계 (예정)
- `02_create_ov_resources.yml` — 수집된 정보로 OpenShift Virtualization 4.20의 `VirtualMachine`, `DataVolume`, `NetworkAttachmentDefinition` 리소스 생성
- 디스크 변환은 MTV(Forklift) 또는 virt-v2v + CDI 중 선택

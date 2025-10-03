# Quality Requirements

## Quality Goals

Ranked by importance, descending:

| Category | Quality | Description | Related Scenarios |
|----------|---------|-------------|-------------------|
| Usability | Operability | The system, services and apps should be easy to operate and update for non-technical users. | SC1, SC2, SC7 |
|           | Accessibility | The system, services and apps should be accessible on most devices. | SC4, SC7 |
| Maintainability |  | The project should be easy to maintain and evolve. Otherwise, as a side project, it is not sustainable | SC3 |
|                 | Testability | Changes should be easily verifiable, either locally or in CI | SC3 |
|                 | Updatability | The system, services and apps should be easy to update | SC2 |
| Security | | Wolkenschloss should be as secure as possible. The security is only limited by the security of the integrated applications and services. | |
|          | Confidentiality | Data should be protected from unauthorized access, only the owners and allowed users should be able to access the Wolkenschloss | |
| Reliability | Maturity | The system should be stable and the apps and services should be mature projects with large communities | SC4 |
|             | Recoverability | After software and hardware failures, the system can be recoverd | SC5 |
| Cost Efficiency | | Self hosting Wolkenschloss should not cost more than subsciption based alternatives | |

## Quality Scenarios

| ID | Scenario |
|----|----------|
| SC1 | A user that can assemble a desktop PC can deploy Wolkenschloss on a machine without any further knowledge. |
| SC2 | A non-technical user can update Wolkenschloss without breaking it. |
| SC3 | A possible contributor can understand the architecture and codebase of Wolkenschloss quickly and be able to make changes confidently. |
| SC4 | A user can access the services and apps on a wide range of devices, including mobile phones and tablets. |
| SC5 | A user can recover from a hardware failure with no data loss. |
| SC6 | Updating system dependencies, services and apps should be easy and quick for maintainers. |
| SC7 | A user does not have to choose services and apps. Instead, the maintainers curate a set of apps and services for the most common use cases. |
| SC8 | Technical users can customize and extend Wolkenschloss to their needs. |
| SC9 | A user can use a wide range of hardware, including older and less powerful devices to self host the project. |
